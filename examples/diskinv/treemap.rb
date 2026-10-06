# frozen_string_literal: true

module DiskInv
  # The scanned tree, indexed for the treemap: children of each folder (largest first), each
  # path's subtree size and file count, and the kinds by total size.
  class Index
    Kind = Data.define(:name, :bytes, :files, :color)

    # Disk Inventory X-like hues, given to kinds by total size; the rest are grey.
    PALETTE = [
      [70, 130, 220], [220, 70, 70], [80, 180, 80], [230, 180, 40], [170, 90, 200], [50, 190, 190],
      [240, 130, 50], [200, 90, 150], [140, 160, 60], [110, 110, 220], [180, 120, 80], [90, 160, 130]
    ].freeze
    OTHER = [120, 120, 120].freeze
    FOLDER = [85, 85, 85].freeze

    attr_reader :rows, :kinds

    def initialize(rows)
      @rows = rows
      @by_path = rows.to_h { |r| [r.path, r] }
      @children = Hash.new { |h, k| h[k] = [] }
      @size = Hash.new(0)
      @files = Hash.new(0)
      rows.each { |r| @children[r.parent] << r if r.parent }
      rows.reverse_each do |r| # children were found after their parents
        @size[r.path] += r.size
        @files[r.path] += r.files
        next unless r.parent

        @size[r.parent] += @size[r.path]
        @files[r.parent] += @files[r.path]
      end
      @children.each_value { |kids| kids.sort_by! { |k| -@size[k.path] } }
      @kinds = build_kinds
      @colors = @kinds.to_h { |k| [k.name, k.color] }
    end

    def [](path) = @by_path[path]
    def children(path) = @children.fetch(path, [])
    def size(path) = @size[path]
    def files(path) = @files[path]
    def color(entry) = entry.dir? ? FOLDER : @colors.fetch(entry.kind, OTHER)

    # The folder and its ancestors up to the root, outermost first.
    def ancestors(path)
      chain = []
      while (entry = @by_path[path]&.parent)
        chain.unshift(entry)
        path = entry
      end
      chain
    end

    private

    def build_kinds
      totals = Hash.new { |h, k| h[k] = [0, 0] }
      @rows.each do |r|
        next if r.dir?

        t = totals[r.kind]
        t[0] += r.size
        t[1] += 1
      end
      totals.sort_by { |_, (bytes, _)| -bytes }.each_with_index.map do |(name, (bytes, files)), i|
        Kind.new(name:, bytes:, files:, color: PALETTE.fetch(i, OTHER))
      end
    end
  end

  # A squarified treemap (Bruls, Huizing, van Wijk) of one folder, drawn into terminal cells.
  class Treemap
    Node = Data.define(:entry, :x, :y, :w, :h, :leaf, :tone)
    ASPECT = 2.0 # a cell is about twice as tall as it is wide
    TINY = ASPECT / 8 # layout area of an eighth of a cell

    attr_reader :width, :height, :nodes

    def initialize(index, root, width, height)
      @index = index
      @width = width
      @height = height
      @nodes = []
      @by_path = {}
      @cells = Array.new(height) { Array.new(width) }
      return if width <= 0 || height <= 0 || index.size(root).zero?

      place(index[root], 0.0, 0.0, width.to_f, height * ASPECT)
    end

    # The file (or folder too small to split) drawn at cell x, y.
    def at(x, y) = (0...@width).cover?(x) && (0...@height).cover?(y) ? @cells[y][x]&.entry : nil

    # The cell rectangle [x, y, w, h] where `path` was drawn, or nil.
    def rect(path)
      node = drawn(path)
      node && [node.x, node.y, node.w, node.h]
    end

    # The node for `path`, or for its nearest drawn ancestor (small files merge into their folder).
    def drawn(path)
      while path
        return @by_path[path] if @by_path.key?(path)

        path = @index[path]&.parent
      end
      nil
    end

    # ANSI lines: each kind's colour, shaded so neighbours stay apart, names where they fit, and
    # `selected` (a path) outlined.
    def lines(selected = nil)
      chars = Array.new(@height) { Array.new(@width, " ") }
      fg = Array.new(@height) { Array.new(@width) }
      @nodes.each { |n| label(n, chars, fg) if n.leaf }
      outline(selected, chars, fg) if selected

      @cells.each_with_index.map do |row, y|
        line = +""
        last = nil
        row.each_with_index do |node, x|
          style = node ? sgr(node, fg[y][x]) : "0"
          line << "\e[0m\e[#{style}m" unless style == last
          last = style
          line << chars[y][x]
        end
        line << "\e[0m"
      end
    end

    private

    def place(entry, x, y, w, h)
      kids = entry.dir? ? @index.children(entry.path).reject { |k| @index.size(k.path).zero? } : []
      cx, cy, cw, ch = cell_rect(x, y, w, h)
      return if cw <= 0 || ch <= 0

      leaf = kids.empty? || cw < 2 || ch < 2
      node = Node.new(entry:, x: cx, y: cy, w: cw, h: ch, leaf:, tone: @nodes.size.odd? ? 0.78 : 1.0)
      @nodes << node
      @by_path[entry.path] = node
      if leaf
        ch.times { |dy| cw.times { |dx| @cells[cy + dy][cx + dx] = node } }
        return
      end

      squarify(entry, kids, x, y, w, h, @index.size(entry.path).to_f)
    end

    # Lays `kids` (largest first) out in rows along the shorter side, keeping each row's
    # rectangles as square as possible. Files smaller than a fraction of a cell aren't laid out one
    # by one: the space they share is drawn as their folder.
    def squarify(parent, kids, x, y, w, h, total)
      scale = w * h / total
      areas = kids.map { |k| @index.size(k.path) * scale }
      i = 0
      while i < kids.size
        if areas[i] < TINY
          fill(parent, x, y, w, h)
          return
        end

        side = [w, h].min
        sum = min = max = areas[i]
        j = i + 1
        while j < kids.size
          a = areas[j]
          break if worst(sum + a, [min, a].min, max, side) > worst(sum, min, max, side)

          sum += a
          min = a if a < min
          j += 1
        end
        # The last row and the last rectangle in each take whatever is left, so float error can't
        # leave a gap of unfilled cells along the parent's edge.
        last = j == kids.size
        if w >= h # a column on the left
          cw = last ? w : sum / h
          oy = y
          (i...j).each do |k|
            kh = k == j - 1 ? y + h - oy : areas[k] / cw
            place(kids[k], x, oy, cw, kh)
            oy += kh
          end
          x += cw
          w -= cw
        else # a row along the top
          rh = last ? h : sum / w
          ox = x
          (i...j).each do |k|
            kw = k == j - 1 ? x + w - ox : areas[k] / rh
            place(kids[k], ox, y, kw, rh)
            ox += kw
          end
          y += rh
          h -= rh
        end
        i = j
      end
    end

    def worst(sum, min, max, side)
      return Float::INFINITY if sum.zero? || side.zero?

      s2 = side * side
      [s2 * max / (sum * sum), sum * sum / (s2 * min)].max
    end

    # Draws the rest of a folder's space (its many small files) as the folder.
    def fill(entry, x, y, w, h)
      cx, cy, cw, ch = cell_rect(x, y, w, h)
      return if cw <= 0 || ch <= 0

      node = Node.new(entry:, x: cx, y: cy, w: cw, h: ch, leaf: false, tone: 1.0)
      ch.times { |dy| cw.times { |dx| @cells[cy + dy][cx + dx] = node } }
    end

    # Float layout space (height in ASPECT units) → whole cells, so neighbours share edges.
    def cell_rect(x, y, w, h)
      x0 = x.round.clamp(0, @width)
      x1 = (x + w).round.clamp(0, @width)
      y0 = (y / ASPECT).round.clamp(0, @height)
      y1 = ((y + h) / ASPECT).round.clamp(0, @height)
      [x0, y0, x1 - x0, y1 - y0]
    end

    def sgr(node, fg)
      r, g, b = @index.color(node.entry)
      t = node.tone
      bg = "48;2;#{(r * t).round};#{(g * t).round};#{(b * t).round}"
      fg ? "#{bg};#{fg}" : bg
    end

    def label(node, chars, fg)
      return if node.w < 8 || node.h < 2

      # One char per cell: control characters (escape sequences) and wide or zero-width ones become "?".
      text = node.entry.name.dup.force_encoding(Encoding::UTF_8).scrub("?").each_char.map do |c|
        cp = c.ord
        cp < 0x20 || (0x7f..0x9f).cover?(cp) || R2UI::Canvas.cell_width(cp) != 1 ? "?" : c
      end.join[0, node.w - 1]
      dark = "38;2;20;20;20"
      text.each_char.with_index do |c, i|
        chars[node.y][node.x + i] = c
        fg[node.y][node.x + i] = dark
      end
    end

    # A frame around the selected node, or the nearest drawn folder holding it (solid if it is a
    # single cell wide or tall).
    def outline(path, chars, fg)
      node = drawn(path)
      return unless node

      x0, y0 = node.x, node.y
      x1, y1 = node.x + node.w - 1, node.y + node.h - 1
      mark = ->(x, y, c) { chars[y][x] = c; fg[y][x] = "1;38;2;255;255;255" }
      if node.w < 2 || node.h < 2
        (y0..y1).each { |y| (x0..x1).each { |x| mark.(x, y, "█") } }
        return
      end

      (x0 + 1...x1).each { |x| mark.(x, y0, "━"); mark.(x, y1, "━") }
      (y0 + 1...y1).each { |y| mark.(x0, y, "┃"); mark.(x1, y, "┃") }
      mark.(x0, y0, "┏"); mark.(x1, y0, "┓"); mark.(x0, y1, "┗"); mark.(x1, y1, "┛")
    end
  end
end
