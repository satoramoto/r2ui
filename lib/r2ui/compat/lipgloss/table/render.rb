# frozen_string_literal: true

# Table state and rendering: a port of Go lipgloss v1.1.0 table/table.go, resizing.go, rows.go and
# util.go. Lipgloss::Table (table.rb) is the gem-facing wrapper.
module R2UI
  module Compat
    module Gloss
      class TableRender
        HEADER_ROW = -1

        # The Go *Table fields that persist between calls (rows.go StringData is folded in).
        class State
          attr_accessor :border, :border_top, :border_bottom, :border_left, :border_right, :border_header,
                        :border_column, :border_row, :border_style, :headers, :data_rows, :data_columns,
                        :width, :height, :use_manual_height, :offset, :wrap, :style_map, :widths, :heights

          def initialize
            @style_map = nil
            @border = Borders.fetch(:rounded)
            @border_top = true
            @border_bottom = true
            @border_left = true
            @border_right = true
            @border_header = true
            @border_column = true
            @border_row = false
            @border_style = nil
            @headers = []
            @width = 0
            @height = 0
            @use_manual_height = false
            @offset = 0
            @wrap = true
            @widths = []
            @heights = []
            clear_rows
          end

          def clear_rows
            @data_rows = []
            @data_columns = 0
          end

          # StringData.Append
          def append(row)
            @data_columns = row.length if row.length > @data_columns
            @data_rows << row
          end

          # StringData.At
          def at(row, cell)
            r = @data_rows[row]
            return "" if r.nil? || cell >= r.length

            r[cell]
          end
        end

        class << self
          # [][]string unmarshal of rows.to_json: each element must be an Array of JSON strings (or null).
          def json_rows(rows)
            rows.map do |r|
              case r
              when nil then []
              when Array
                strs = Layout.json_strings(r)
                return nil if strs.equal?(Layout::JSON_FAIL)

                strs
              else return nil
              end
            end
          end

          # TypedData_Get_Struct(value, ..., &style_type, ...)
          def check_style(value)
            return if value.is_a?(::Lipgloss::Style)

            raise TypeError, "wrong argument type #{Layout.type_name(value)} (expected Lipgloss::Style)"
          end

          def new_style = ::Lipgloss::Style.new
        end

        def initialize(state)
          @t = state
          @default_style = self.class.new_style
          @border_style = state.border_style || @default_style
          @b = state.border
        end

        # Table.String
        def render
          t = @t
          has_headers = !t.headers.empty?
          has_rows = !t.data_rows.empty?
          return +"" if !has_headers && !has_rows

          if has_headers
            (t.headers.length...t.data_columns).each { t.headers << "" }
          end

          resize

          sb = +""
          if t.border_top
            sb << construct_top_border << "\n"
          end
          sb << construct_headers << "\n" if has_headers

          bottom = t.border_bottom ? construct_bottom_border : +""

          if has_rows
            if t.use_manual_height
              top_height = Layout.height(sb) - 1
              available = t.height - (top_height + Layout.height(bottom))
              available = t.data_rows.length if available > t.data_rows.length
              sb << construct_rows(available)
            else
              (t.offset...t.data_rows.length).each { |r| sb << construct_row(r, false) }
            end
          end

          sb << bottom

          @default_style.max_height(compute_height).max_width(t.width).send(:go_render, sb)
        end

        private

        def brender(str) = @border_style.send(:go_render, str)

        # Table.style / the gem's map-backed StyleFunc.
        def style(row, col)
          map = @t.style_map
          return @default_style if map.nil?

          map["#{row},#{col}"] || @default_style
        end

        def btoi(b) = b ? 1 : 0

        def compute_height
          t = @t
          t.heights.sum - 1 + btoi(!t.headers.empty?) + btoi(t.border_top) + btoi(t.border_bottom) +
            btoi(t.border_header) + (t.data_rows.length * btoi(t.border_row))
        end

        def construct_top_border
          s = +""
          s << brender(@b.top_left) if @t.border_left
          widths = @t.widths
          widths.each_with_index do |w, i|
            s << brender(@b.top * w)
            s << brender(@b.middle_top) if i < widths.length - 1 && @t.border_column
          end
          s << brender(@b.top_right) if @t.border_right
          s
        end

        def construct_bottom_border
          s = +""
          s << brender(@b.bottom_left) if @t.border_left
          widths = @t.widths
          widths.each_with_index do |w, i|
            s << brender(@b.bottom * w)
            s << brender(@b.middle_bottom) if i < widths.length - 1 && @t.border_column
          end
          s << brender(@b.bottom_right) if @t.border_right
          s
        end

        def construct_headers
          t = @t
          headers = t.headers
          s = +""
          s << brender(@b.left) if t.border_left
          headers.each_with_index do |header, i|
            w = t.widths[i]
            s << style(HEADER_ROW, i).max_height(1).width(w).max_width(w)
                                     .send(:go_render, Text.truncate(header, w, "…"))
            s << brender(@b.left) if i < headers.length - 1 && t.border_column
          end
          if t.border_header
            s << brender(@b.right) if t.border_right
            s << "\n"
            s << brender(@b.middle_left) if t.border_left
            headers.length.times do |i|
              s << brender(@b.top * t.widths[i])
              s << brender(@b.middle) if i < headers.length - 1 && t.border_column
            end
            s << brender(@b.middle_right) if t.border_right
          end
          s << brender(@b.right) if t.border_right && !t.border_header
          s
        end

        def construct_rows(available_lines)
          t = @t
          n = t.data_rows.length
          sb = +""
          offset_row_count = n - t.offset
          rows_to_render = [available_lines, 1].max
          needs_overflow = rows_to_render < offset_row_count
          row_idx = needs_overflow ? t.offset : n - rows_to_render
          while rows_to_render.positive? && row_idx < n
            is_overflow = needs_overflow && rows_to_render == 1
            sb << construct_row(row_idx, is_overflow)
            row_idx += 1
            rows_to_render -= 1
          end
          sb
        end

        def construct_row(index, is_overflow)
          t = @t
          has_headers = !t.headers.empty?
          height = t.heights.fetch(index + btoi(has_headers))
          height = 1 if is_overflow

          cells = []
          left = (brender(@b.left) + "\n") * height
          cells << left if t.border_left

          columns = t.data_columns
          columns.times do |c|
            cell_width = t.widths[c]
            cell = is_overflow ? "…" : t.at(index, c)
            cs = style(index, c)
            unless t.wrap
              length = (cell_width * height) - cs.send(:get_horizontal_padding)
              cell = Text.truncate(cell, length, "…")
            end
            cells << cs.height(height - cs.send(:get_vertical_margins))
                       .max_height(height)
                       .width(cell_width - cs.send(:get_horizontal_margins))
                       .max_width(cell_width)
                       .send(:go_render, cell)
            cells << left if c < columns - 1 && t.border_column
          end

          cells << ((brender(@b.right) + "\n") * height) if t.border_right

          # Right-trim newlines with a byte scan; /\n+\z/ backtracks quadratically.
          cells.map! do |cell|
            i = cell.bytesize
            i -= 1 while i.positive? && cell.getbyte(i - 1) == 10
            i == cell.bytesize ? cell : cell.byteslice(0, i)
          end

          s = +""
          s << Layout.join_horizontal(0.0, cells) << "\n"

          if t.border_row && index < t.data_rows.length - 1
            s << brender(@b.middle_left)
            t.widths.each_with_index do |w, i|
              s << brender(@b.bottom * w)
              s << brender(@b.middle) if i < t.widths.length - 1 && t.border_column
            end
            s << brender(@b.middle_right) << "\n"
          end
          s
        end

        # --- resizing.go ---------------------------------------------------------------------------

        Column = Struct.new(:index, :min, :max, :median, :rows, :x_padding, :fixed_width)

        def resize
          t = @t
          has_headers = !t.headers.empty?
          ncols = t.data_columns
          rows = t.data_rows.each_index.map { |i| Array.new(ncols) { |j| t.at(i, j) } }
          all_rows = has_headers ? [t.headers] + rows : rows

          r = Resizer.new(t.width, t.headers, all_rows)
          r.wrap = t.wrap
          r.border_column = t.border_column
          r.y_paddings = Array.new(all_rows.length)
          r.row_heights = r.default_row_heights

          all_rows.each_with_index do |row, i|
            r.y_paddings[i] = Array.new(row.length, 0)
            row.each_index do |j|
              column = r.columns[j]
              row_index = has_headers ? i - 1 : i
              st = style(row_index, j)
              mt, mr, mb, ml = st.send(:get_margin)
              pt, pr, pb, pl = st.send(:get_padding)
              column.x_padding = [column.x_padding, ml + mr + pl + pr].max
              column.fixed_width = [column.fixed_width, Gloss::TableRender.style_width(st)].max
              r.row_heights[i] = [r.row_heights[i], Gloss::TableRender.style_height(st)].max
              r.y_paddings[i][j] = mt + mb + pt + pb
            end
          end

          r.table_width = r.detect_table_width if r.table_width <= 0

          t.widths, t.heights = r.optimized_widths
        end

        class << self
          # Style.GetWidth / GetHeight
          def style_width(st) = st.send(:get_width)
          def style_height(st) = st.send(:get_height)
        end

        class Resizer
          INT32_MAX = 2_147_483_647

          attr_accessor :table_width, :all_rows, :row_heights, :columns, :wrap, :border_column, :y_paddings

          def initialize(table_width, headers, all_rows)
            @table_width = table_width
            @headers = headers
            @all_rows = all_rows
            @row_heights = []
            @y_paddings = []
            @columns = []

            all_rows.each do |row|
              row.each_with_index do |cell, i|
                cell_len = Layout.width(cell)
                if @columns.length <= i
                  @columns << Column.new(i, cell_len, cell_len, cell_len, [], 0, 0)
                  next
                end
                col = @columns[i]
                col.rows << row
                col.min = cell_len if cell_len < col.min
                col.max = cell_len if cell_len > col.max
              end
            end
            @columns.each_with_index do |col, j|
              col.median = median(col.rows.map { |row| Layout.width(row[j]) })
            end
          end

          def optimized_widths
            max_total <= @table_width ? expand_table_width : shrink_table_width
          end

          def detect_table_width
            max_char_count + total_horizontal_padding + total_horizontal_border
          end

          def expand_table_width
            col_widths = max_column_widths
            loop do
              total = col_widths.sum + total_horizontal_border
              break if total >= @table_width

              shorter_index = 0
              shorter_width = INT32_MAX
              col_widths.each_with_index do |w, j|
                next if w == @columns[j].fixed_width

                if w < shorter_width
                  shorter_width = w
                  shorter_index = j
                end
              end
              col_widths[shorter_index] += 1
            end
            [col_widths, expand_row_heights(col_widths)]
          end

          def shrink_table_width
            col_widths = max_column_widths

            shrink_biggest = lambda do |very_big_only|
              loop do
                total = col_widths.sum + total_horizontal_border
                break if total <= @table_width

                big_index = -INT32_MAX
                big_width = -INT32_MAX
                col_widths.each_with_index do |w, j|
                  next if w == @columns[j].fixed_width

                  if very_big_only
                    if w >= go_div(@table_width, 2) && w > big_width
                      big_width = w
                      big_index = j
                    end
                  elsif w > big_width
                    big_width = w
                    big_index = j
                  end
                end
                break if big_index.negative? || col_widths[big_index].zero?

                col_widths[big_index] -= 1
              end
            end

            shrink_to_median = lambda do
              loop do
                total = col_widths.sum + total_horizontal_border
                break if total <= @table_width

                biggest_diff = -INT32_MAX
                biggest_index = -INT32_MAX
                col_widths.each_with_index do |w, j|
                  next if w == @columns[j].fixed_width

                  diff = w - @columns[j].median
                  if diff.positive? && diff > biggest_diff
                    biggest_diff = diff
                    biggest_index = j
                  end
                end
                break if biggest_index <= 0 || col_widths[biggest_index].zero?

                col_widths[biggest_index] -= 1
              end
            end

            shrink_biggest.call(true)
            shrink_to_median.call
            shrink_biggest.call(false)

            [col_widths, expand_row_heights(col_widths)]
          end

          def expand_row_heights(col_widths)
            heights = default_row_heights
            return heights unless @wrap

            @all_rows.each_with_index do |row, i|
              row.each_with_index do |cell, j|
                h = detect_content_height(cell, col_widths[j] - x_padding_for_col(j)) + x_padding_for_cell(i, j)
                heights[i] = h if h > heights[i]
              end
            end
            heights
          end

          def default_row_heights
            Array.new(@all_rows.length) do |i|
              h = i < @row_heights.length ? @row_heights[i] : 0
              h < 1 ? 1 : h
            end
          end

          def max_column_widths
            @columns.map do |col|
              col.fixed_width.positive? ? col.fixed_width : col.max + x_padding_for_col(col.index)
            end
          end

          def max_char_count
            @columns.sum do |col|
              col.fixed_width.positive? ? col.fixed_width - x_padding_for_col(col.index) : col.max
            end
          end

          def max_total
            total = 0
            @columns.each_with_index do |col, j|
              total += col.fixed_width.positive? ? col.fixed_width : col.max + x_padding_for_col(j)
            end
            total
          end

          def total_horizontal_padding = @columns.sum(&:x_padding)

          def x_padding_for_col(j)
            j >= @columns.length ? 0 : @columns[j].x_padding
          end

          def x_padding_for_cell(i, j)
            return 0 if i >= @y_paddings.length || @y_paddings[i].nil? || j >= @y_paddings[i].length

            @y_paddings[i][j]
          end

          def total_horizontal_border
            (@columns.length * border_per_cell) + extra_border
          end

          def border_per_cell = @border_column ? 1 : 0
          def extra_border = @border_column ? 1 : 0

          def detect_content_height(content, width)
            return 1 if width.zero?

            content = content.gsub("\r\n", "\n")
            content.split("\n", -1).then { |ls| ls.empty? ? [""] : ls }.sum do |line|
              Text.wrap(line, width, "").count("\n") + 1
            end
          end

          private

          # util.go median (integer division truncates toward zero; widths are non-negative).
          def median(n)
            n = n.sort
            return 0 if n.empty?

            if n.length.even?
              h = n.length / 2
              (n[h - 1] + n[h]) / 2
            else
              n[n.length / 2]
            end
          end

          # Go integer division truncates toward zero.
          def go_div(a, b)
            q = a.abs / b.abs
            (a.negative? ^ b.negative?) ? -q : q
          end
        end
      end
    end
  end
end
