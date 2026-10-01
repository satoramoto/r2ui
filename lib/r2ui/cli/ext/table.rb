# frozen_string_literal: true

# c10-table: tables, like `npm outdated` or `pnpm ls --long`.
#
#   table([["rails", "7.1.0", "12 kB"], ["pg", "1.5", "1.2 MB"]],
#         headers: %w[Name Version Size], align: { 2 => :right })
#
#   table([{ app: "api", state: "up" }, { app: "web", state: "down" }])   # headers from the keys
#
# On a terminal (Shell#live?) it draws a Lipgloss::Table with a rounded border (muted) and a bold
# header, sized to its content and shrunk (wrapping cells) when wider than the shell:
#
#   ╭───────┬─────────┬────────╮
#   │ Name  │ Version │   Size │
#   ├───────┼─────────┼────────┤
#   │ rails │ 7.1.0   │  12 kB │
#   │ pg    │ 1.5     │ 1.2 MB │
#   ╰───────┴─────────┴────────╯
#
# Off a terminal (a pipe, CI, TERM=dumb) it prints plain columns separated by two spaces, no
# border, no colour, no trailing spaces, one line per row (newlines in a cell become spaces), so
# `tool ls | awk '{print $1}'` works:
#
#   Name   Version    Size
#   rails  7.1.0     12 kB
#   pg     1.5      1.2 MB
#
# Rows are Arrays (short ones are padded) or Hashes. With Hash rows and no `headers:`, the headers
# are the keys in the order they first appear; with `headers:`, they pick and order the columns.
# Cells are shown with #to_s (nil is blank) and measured by display width, so wide characters and
# already-painted text line up. `align:` maps a column (0-based index, or its header) to :left,
# :right or :center. With no rows only the header prints; with neither, nothing. Writes to stdout
# through the Shell (above a running Live region) and returns nil.
module R2UI
  module CLI
    module Ext
      module Tabulate
        ALIGNMENTS = { left: Lipgloss::LEFT, right: Lipgloss::RIGHT, center: Lipgloss::CENTER }.freeze
        GAP = "  "

        module_function

        # [headers or nil, rows as Arrays of Strings, all the same length].
        def normalize(rows, headers)
          rows = rows.to_a
          if rows.any? { |row| row.is_a?(Hash) }
            keys = headers || rows.flat_map { |row| row.to_h.keys }.uniq
            rows = rows.map { |row| row.is_a?(Hash) ? keys.map { |key| lookup(row, key) } : Array(row) }
            headers = keys
          else
            rows = rows.map { |row| Array(row) }
          end
          headers = headers&.map { |cell| text(cell) }
          count = [headers&.size || 0, *rows.map(&:size)].max
          rows = rows.map { |row| Array.new(count) { |i| text(row[i]) } }
          headers = Array.new(count) { |i| headers[i] || "" } if headers
          [headers, rows]
        end

        def lookup(row, key)
          [key, key.to_s, key.respond_to?(:to_sym) ? key.to_sym : key].each do |k|
            return row[k] if row.key?(k)
          end
          nil
        end

        def text(cell) = cell.nil? ? "" : cell.to_s

        # { column index => :left/:right/:center } from indexes or header names.
        def alignments(align, headers)
          (align || {}).to_h do |column, side|
            raise ArgumentError, "align: #{side.inspect} isn't :left, :right or :center" unless ALIGNMENTS.key?(side)

            index = column.is_a?(Integer) ? column : headers&.index(column.to_s)
            raise ArgumentError, "align: no column #{column.inspect}" unless index

            [index, side]
          end
        end

        def width(text) = Lipgloss.width(text)

        def plain(headers, rows, align)
          lines = headers ? [headers, *rows] : rows
          return [] if lines.empty?

          lines = lines.map { |cells| cells.map { |cell| cell.gsub(/\s*\R\s*/, " ") } }
          widths = lines.transpose.map { |column| column.map { |cell| width(cell) }.max }
          lines.map do |cells|
            cells.each_with_index.map { |cell, i| pad(cell, widths[i], align[i]) }.join(GAP).rstrip
          end
        end

        def pad(cell, size, side)
          space = size - width(cell)
          case side
          when :right then (" " * space) + cell
          when :center then (" " * (space / 2)) + cell + (" " * (space - (space / 2)))
          else cell + (" " * space)
          end
        end

        def boxed(shell, headers, rows, align)
          return [] if headers.nil? && rows.empty?

          columns = (headers || rows.first).size
          color = shell.color?
          cell = Lipgloss::Style.new.padding(0, 1)
          head = color ? cell.bold(true) : cell
          table = Lipgloss::Table.new.border(:rounded).rows(rows)
          table = table.headers(headers) if headers
          table = table.border_header(false) if rows.empty? # no rule above an empty body
          table = table.border_style(shell.theme.style(:muted)) if color
          table = table.style_func(rows: rows.size, columns:) do |row, column|
            style = row == Lipgloss::Table::HEADER_ROW ? head : cell
            (side = align[column]) ? style.align(ALIGNMENTS.fetch(side)) : style
          end
          out = table.render
          out = table.width(shell.width).render if out.lines.any? { |line| width(line.chomp) > shell.width }
          out.split("\n")
        end
      end
    end

    extension :table do
      helpers do
        def table(rows, headers: nil, align: nil)
          headers, rows = Ext::Tabulate.normalize(rows, headers)
          align = Ext::Tabulate.alignments(align, headers)
          lines = if shell.live?
                    Ext::Tabulate.boxed(shell, headers, rows, align)
                  else
                    Ext::Tabulate.plain(headers, rows, align)
                  end
          lines.each { |line| shell.puts(line) }
          nil
        end
      end
    end
  end
end
