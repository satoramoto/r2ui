# frozen_string_literal: true

# A Disk Inventory X clone: where the space in a folder went, as a tree, a treemap and file kinds.
#   ruby examples/diskinv.rb [FOLDER]                       (default: the current folder)
#   DISKINV_ROOT=~/Downloads exe/r2ui examples/diskinv.rb
#   exe/r2ui --snapshot --width 140 --height 45 examples/diskinv.rb
#
# The tree fills in while the scan runs. Selecting a line outlines it in the treemap; clicking the
# treemap selects that file in the tree. + zooms the treemap into the selected folder, - zooms out,
# o reveals the selection in Finder. Search (/) looks through the lines the tree has unfolded.

require_relative "../lib/r2ui"
require "set"
require_relative "diskinv/scanner"
require_relative "diskinv/treemap"

module DiskInv
  ROOT = File.expand_path(($PROGRAM_NAME == __FILE__ && ARGV.first) || ENV["DISKINV_ROOT"] || Dir.pwd)

  # A tree line: a file, or a folder with its whole subtree's size and file count.
  Line = Data.define(:path, :parent, :name, :size, :files, :kind)

  module_function

  SCANNER_LOCK = Mutex.new

  # Exactly one scanner, whichever thread (feed or update) asks first.
  def scanner = @scanner || SCANNER_LOCK.synchronize { @scanner ||= Scanner.new(ROOT).start }
  def index = scanner.snapshot.index
  def panel(app, name) = app.dashboard.panels.find { |p| p.name == name }

  # The tree's rows. A big scan has far too many rows to hand the table every frame, so it gets
  # the unfolded folders' contents only, plus one level more so folded folders can unfold at once.
  # Built on the update thread by `sync`; before that (a snapshot), with everything folded.
  def rows = @rows || visible(index, Set.new, Set.new)

  def visible(idx, collapsed, seen)
    root = idx[scanner.root] or return []
    lines = [line(idx, root)]
    open = [root.path]
    while (dir = open.pop)
      idx.children(dir).each do |entry|
        lines << line(idx, entry)
        next unless entry.dir? && !idx.children(entry.path).empty?

        collapsed << entry.path if seen.add?(entry.path) # new folders start folded
        if collapsed.include?(entry.path)
          idx.children(entry.path).each { |kid| lines << line(idx, kid) }
        else
          open << entry.path
        end
      end
    end
    lines
  end

  def line(idx, entry)
    Line.new(path: entry.path, parent: entry.parent, name: entry.name, size: idx.size(entry.path),
             files: idx.files(entry.path), kind: entry.kind)
  end

  # Runs on a timer: rebuilds the rows when the scan publishes or a folder (un)folds.
  def sync(ctx)
    snap = scanner.snapshot
    collapsed = ctx.app.panel_state(panel(ctx.app, :file)).collapsed
    key = [snap.index, collapsed.hash]
    return if key == @synced

    @seen ||= Set.new
    @rows = visible(snap.index, collapsed, @seen).freeze
    @synced = [snap.index, collapsed.hash]
    ctx.refresh(:file)
    return unless snap.done && !@announced

    @announced = true
    ctx.flash "Scanned #{snap.rows.size} items in #{snap.seconds.round(1)}s"
  end

  # The entry on the tree's selected line.
  def selected(app)
    tree = panel(app, :file)
    app.panel_lines(tree)[app.panel_state(tree).selected]&.rows&.first
  end

  def zoom_root = @zoom && index[@zoom] ? @zoom : scanner.root

  def zoom_in(app)
    entry = selected(app) or return
    @zoom = index[entry.path]&.dir? ? entry.path : entry.parent
  end

  def zoom_out
    @zoom = index[zoom_root]&.parent if zoom_root != scanner.root
  end

  def treemap_view(app, width, height)
    @treemap = Treemap.new(index, zoom_root, width, height)
    @treemap.lines(selected(app)&.path).join("\n")
  end

  # A click on the treemap selects that file in the tree, unfolding its folders.
  def click(ctx, msg)
    app = ctx.app
    rect = app.panel_rects[panel(app, :treemap)]&.inner
    entry = rect && @treemap&.at(msg.x - rect.x, msg.y - rect.y) or return
    tree = panel(app, :file)
    state = app.panel_state(tree)
    (@seen ||= Set.new).merge(index.ancestors(entry.path)) # so sync doesn't fold them as new
    index.ancestors(entry.path).each { |path| state.collapsed.delete(path) }
    sync(ctx)
    lines = R2UI::Query.new(R2UI.registry.resource(:file), @rows, scope: state.scope, grouping: state.grouping,
                                                                   search: state.search, sort: state.sort,
                                                                   collapsed: state.collapsed).lines
    at = lines.index { |l| l.id == entry.path }
    state.move(at - state.selected, lines.size) if at
  end

  # Totals, then the kinds by total size, each with its treemap colour.
  def legend(width, height)
    snap = scanner.snapshot
    idx = snap.index
    return "Can't scan #{scanner.root}: #{snap.error}"[0, width] if snap.error

    head = "#{snap.done ? "" : "Scanning… "}#{R2UI::Format.bytes(idx.size(scanner.root))} in " \
           "#{idx.files(scanner.root)} files"
    zoom = zoom_root == scanner.root ? nil : "zoom: …#{zoom_root.delete_prefix(scanner.root)}"
    lines = [head, zoom].compact.map { |l| l[0, width] }
    idx.kinds.first([height - lines.size, 0].max).each do |k|
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
  on_key("o", help: "reveal") do
    entry = DiskInv.selected(app)
    system("open", "-R", entry.path) if entry
  end

  row height: 16 do
    panel :file, span: 3, title: "Files" do
      table group_by: :folder
    end
    panel :kinds, resource: nil, span: 1 do
      view { DiskInv.legend(width, height) }
    end
  end

  row do
    panel :treemap, resource: nil do
      view { DiskInv.treemap_view(app, width, height) }
    end
  end
end

R2UI.run if $PROGRAM_NAME == __FILE__
