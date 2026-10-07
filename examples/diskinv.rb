# frozen_string_literal: true

# A Disk Inventory X clone: where the space in a folder went, as a tree, a treemap and file kinds.
#   ruby examples/diskinv.rb [FOLDER]                       (default: the current folder)
#   DISKINV_ROOT=~/Downloads exe/r2ui examples/diskinv.rb
#   exe/r2ui --snapshot --width 140 --height 45 examples/diskinv.rb
#
# The tree fills in while the scan runs. Selecting a line outlines it in the treemap; clicking the
# treemap selects that file in the tree. + zooms the treemap into the selected folder, - zooms out.
# o shows the selection in Finder (so does a right-click on the treemap); O opens it (a folder in
# Finder, a file in its app). Search (/) looks through the lines the tree has unfolded.
#
# Sizes are space on disk (allocated blocks, as `du` shows), so online-only Google Drive, iCloud and
# Dropbox files count as nothing; the Kinds panel says how many there are. DISKINV_SIZES=logical
# counts the size each file reports instead.

require_relative "../lib/r2ui"
require "set"
require_relative "diskinv/scanner"
require_relative "diskinv/treemap"

module DiskInv
  ROOT = File.expand_path(($PROGRAM_NAME == __FILE__ && ARGV.first) || ENV["DISKINV_ROOT"] || Dir.pwd)
  RIGHT_BUTTON = 2 # the terminal's SGR button number, which Bubbletea 0.1.4 passes through

  # A tree line: a file, or a folder with its whole subtree's size and file count.
  Line = Data.define(:path, :parent, :name, :size, :files, :kind, :node)

  module_function

  SCANNER_LOCK = Mutex.new

  # Exactly one scanner, whichever thread (feed or update) asks first.
  def scanner = @scanner || SCANNER_LOCK.synchronize { @scanner ||= Scanner.new(ROOT).start }
  def panel(app, name) = app.dashboard.panels.find { |p| p.name == name }

  # The tree's rows. A big scan has far too many rows to hand the table every frame, so it gets
  # the unfolded folders' contents only, plus one level more so folded folders can unfold at once.
  # Built on the update thread by `sync`; before that (a snapshot), with everything folded.
  def rows = @rows || visible(scanner.root, Set.new, Set.new)

  def visible(root, collapsed, seen)
    lines = [line(root)]
    open = [root]
    while (dir = open.pop)
      dir.children.each do |node|
        lines << line(node)
        next unless node.dir? && !node.children.empty?

        collapsed << node.path if seen.add?(node.path) # new folders start folded
        if collapsed.include?(node.path)
          node.children.each { |kid| lines << line(kid) }
        else
          open << node
        end
      end
    end
    lines
  end

  def line(node)
    Line.new(path: node.path, parent: node.parent&.path, name: File.basename(node.name), size: node.size, files: node.files,
             kind: node.kind, node:)
  end

  # Runs on a timer: rebuilds the rows when the scan publishes or a folder (un)folds.
  def sync(ctx)
    snap = scanner.snapshot
    collapsed = ctx.app.panel_state(panel(ctx.app, :file)).collapsed
    return if [snap.generation, collapsed.hash] == @synced

    @seen ||= Set.new
    @rows = visible(snap.root, collapsed, @seen).freeze
    @synced = [snap.generation, collapsed.hash]
    ctx.refresh(:file)
    return unless snap.done && !@announced

    @announced = true
    ctx.flash "Scanned #{snap.root.files} files in #{snap.seconds.round(1)}s"
  end

  # The node on the tree's selected line.
  def selected(app)
    tree = panel(app, :file)
    app.panel_lines(tree)[app.panel_state(tree).selected]&.rows&.first&.node
  end

  def zoom_root = @zoom || scanner.root

  def zoom_in(app)
    node = selected(app) or return
    @zoom = node.dir? ? node : node.parent
  end

  def zoom_out
    @zoom = zoom_root.parent
  end

  TREEMAP_LOCK = Mutex.new

  # The treemap is laid out once per scan generation, zoom and size; each frame only outlines the
  # selection. Locked: the renderer calls this, and so does the mouse extension (on the update
  # thread) when it measures the panel.
  def treemap_view(app, width, height)
    sel = selected(app)
    TREEMAP_LOCK.synchronize do
      snap = scanner.snapshot
      key = [snap.generation, zoom_root.object_id, width, height]
      if key != @treemap_key
        @children ||= Children.new
        @treemap = Treemap.new(zoom_root, width, height, colors: snap.colors, children: @children,
                                                         generation: snap.generation)
        @treemap_key = key
        @treemap_lines = nil
      end
      cached = @treemap_lines
      return cached.last if cached && cached.first.equal?(sel)

      text = @treemap.lines(sel).join("\n")
      @treemap_lines = [sel, text]
      text
    end
  end

  # A click on the treemap selects that file in the tree, unfolding its folders; a right-click
  # also shows it in Finder.
  def click(ctx, msg)
    app = ctx.app
    rect = app.panel_rects[panel(app, :treemap)]&.inner
    node = rect && TREEMAP_LOCK.synchronize { @treemap&.at(msg.x - rect.x, msg.y - rect.y) } or return
    select(ctx, node)
    show_in_finder(node) if msg.button == RIGHT_BUTTON
  end

  def select(ctx, node)
    app = ctx.app
    state = app.panel_state(panel(app, :file))
    folders = node.ancestors.map(&:path)
    (@seen ||= Set.new).merge(folders) # so sync doesn't fold them as new
    folders.each { |path| state.collapsed.delete(path) }
    sync(ctx)
    lines = R2UI::Query.new(R2UI.registry.resource(:file), @rows, scope: state.scope, grouping: state.grouping,
                                                                   search: state.search, sort: state.sort,
                                                                   collapsed: state.collapsed).lines
    at = lines.index { |l| l.id == node.path }
    state.move(at - state.selected, lines.size) if at
  end

  def show_in_finder(node) = node && run_open("-R", node.path)
  def open_node(node) = node && run_open(node.path)
  def run_open(*args) = Process.detach(spawn("open", *args, %i[out err] => File::NULL))

  # Totals, then the kinds by total size, each with its treemap colour.
  def legend(width, height)
    snap = scanner.snapshot
    return "Can't scan #{scanner.root.path}: #{snap.error}"[0, width] if snap.error

    root = snap.root
    head = "#{snap.done ? "" : "Scanning… "}#{R2UI::Format.bytes(root.size)} in #{root.files} files"
    zoom = zoom_root.equal?(root) ? nil : "zoom: …#{zoom_root.path.delete_prefix(root.path)}"
    cloud = if snap.cloud_files.positive?
              "#{snap.cloud_files} cloud-only files (#{R2UI::Format.bytes(snap.cloud_bytes)}) " \
                "#{snap.sizes == :disk ? "not counted" : "counted"}"
            end
    lines = [head, cloud, zoom].compact.map { |l| l[0, width] }
    snap.kinds.first([height - lines.size, 0].max).each do |k|
      swatch = "\e[48;2;#{k.color.join(";")}m  \e[0m"
      name = k.name[0, [width - 22, 4].max].ljust([width - 21, 4].max)
      lines << "#{swatch} #{name}#{R2UI::Format.bytes(k.bytes).rjust(8)} #{k.files.to_s.rjust(8)}"
    end
    lines.join("\n")
  end
end

R2UI.resource :file do
  source { DiskInv.rows }
  refresh every: 2
  key :path, parent: :parent

  group_by :folder, label: "Folders", tree: true

  index do
    column :name
    # Lines carry their subtree totals already, so the tree shows each line's own value.
    column :size, format: :bytes, aggregate: :own, sort: :desc
    column :files, format: :integer, aggregate: :own
    column :kind
  end

  filter :name, :kind
end

R2UI.dashboard do
  title "Disk Inventory · #{DiskInv::ROOT}"
  mouse

  every(0.25) { DiskInv.sync(self) }
  on_click { |msg, panel| DiskInv.click(self, msg) if panel&.name == :treemap }
  on_key("+", "=", help: "zoom in") { DiskInv.zoom_in(app) }
  on_key("-", help: "zoom out") { DiskInv.zoom_out }
  on_key("o", help: "show in Finder") { DiskInv.show_in_finder(DiskInv.selected(app)) }
  on_key("O", help: "open") { DiskInv.open_node(DiskInv.selected(app)) }

  row height: 16 do
    panel :file, span: 3, title: "Files" do
      table group_by: :folder
    end
    panel :kinds, resource: nil, span: 1 do
      view { DiskInv.legend(width, height) }
    end
  end

  row do
    panel :treemap, resource: nil, title: "Treemap (click: select · right-click: show in Finder)" do
      view { DiskInv.treemap_view(app, width, height) }
    end
  end
end

R2UI.run if $PROGRAM_NAME == __FILE__
