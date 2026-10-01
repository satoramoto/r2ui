# frozen_string_literal: true

module R2UI
  module Widgets
    # The index table: header, sort marker, grouped/tree labels, inline sparklines, selection.
    class Table
      SPARK_WIDTH = 10
      MIN_TEXT = 8

      # `spark` is called with (line, column) and returns that line's recent values.
      def initialize(resource, lines, state:, focused:, label_key: nil, spark: nil)
        @resource = resource
        @lines = lines
        @state = state
        @focused = focused
        @spark = spark
        @label_key = label_key || resource.columns.find { |c| !c.numeric? && c.format != :id }&.key
      end

      def draw(canvas, rect)
        return if rect.empty?

        layout = widths(rect.width)
        draw_header(canvas, rect, layout)
        body = rect.with(y: rect.y + 1, height: rect.height - 1)
        @state.scroll_to_selection(body.height, @lines.size)
        @lines.drop(@state.offset).first(body.height).each_with_index do |line, i|
          index = @state.offset + i
          selected = @focused && index == @state.selected
          canvas.fill(body.with(y: body.y + i, height: 1), " ", :selected) if selected
          draw_line(canvas, rect.x, body.y + i, line, layout, selected)
        end
        draw_footer(canvas, rect) if @lines.size > body.height
      end

      private

      def draw_header(canvas, rect, layout)
        sort_key, sort_dir = @state.sort
        x = rect.x
        layout.each do |col, w|
          label = col.label
          label = "#{label}#{sort_dir == :desc ? "▼" : "▲"}" if col.key == sort_key
          canvas.write(x, rect.y, align(label, w, col.align), :header, max: w)
          x += w + 1
        end
      end

      def draw_line(canvas, x, y, line, layout, selected)
        layout.each do |col, w|
          text, style = cell(line, col, w)
          canvas.write(x, y, text, selected ? :selected : style, max: w)
          x += w + 1
        end
      end

      def cell(line, col, width)
        if col.key == @label_key && (line.label || line.depth.positive? || line.expandable?)
          prefix, body, suffix = label_parts(line, col)
          body = fit(body, [width - prefix.length - suffix.length, 1].max, Format.truncate_from(col.format))
          return [fit("#{prefix}#{body}#{suffix}", width, :right), line.label ? :bold : :plain]
        end

        value, text = value_text(line, col)
        if col.sparkline && @spark
          text_w = width - SPARK_WIDTH - 1
          text = "#{Sparkline.line(@spark.call(line, col), SPARK_WIDTH).rjust(SPARK_WIDTH)} #{align(text, text_w, col.align)}"
          return [text, :plain]
        end
        [align(fit(text, width, Format.truncate_from(col.format)), width, col.align), style_for(col, value)]
      end

      # [raw value, rendered text] for a non-label cell.
      def value_text(line, col)
        value = line.values[col.key]
        value = "×#{line.count}" if col.aggregate == :count && line.label
        [value, value.is_a?(String) && col.aggregate == :count ? value : col.render(value)]
      end

      # How wide this cell's text is untruncated: what `cell` would draw given unlimited room.
      def cell_need(line, col)
        if col.key == @label_key && (line.label || line.depth.positive? || line.expandable?)
          return label_parts(line, col).sum(&:length)
        end

        text_need = value_text(line, col)[1].length
        col.sparkline && @spark ? SPARK_WIDTH + 1 + text_need : text_need
      end

      # [indent and tree marker, the value (truncated to fit), count suffix]
      def label_parts(line, col)
        if line.label
          body = Format.call(col.format, line.label)
          counted = @resource.columns.any? { |c| c.aggregate == :count }
          ["", body.empty? ? "(none)" : body, counted ? "" : " ×#{line.count}"]
        else
          marker = if line.expandable? then line.collapsed ? "▸ " : "▾ " else "  " end
          ["#{"  " * line.depth}#{marker}", col.render(line.values[col.key]), line.count > 1 ? " (#{line.count})" : ""]
        end
      end

      def style_for(col, value)
        return :plain unless col.format == :percent && value.is_a?(Numeric)

        if value >= 80 then :alert
        elsif value >= 25 then :warn
        else :plain
        end
      end

      # Fixed-width columns get their width; text columns share the rest by need (see `share`).
      # Drops columns from the right while the text columns can't get MIN_TEXT each.
      def widths(total)
        cols = @resource.columns
        fixed = cols.to_h do |c|
          w = c.width || Format.default_width(c.format)
          w &&= [w, c.label.length + 1].max
          w += SPARK_WIDTH + 1 if w && c.sparkline
          [c, w]
        end
        loop do
          flexible = fixed.count { |_, w| w.nil? }
          used = fixed.values.compact.sum + fixed.size - 1
          spare = total - used
          break if flexible.zero? ? spare >= 0 : spare >= flexible * MIN_TEXT
          break if fixed.size == 1

          fixed.delete(fixed.keys.last)
        end
        flexible = fixed.filter_map { |c, w| c if w.nil? }
        spare = total - fixed.values.compact.sum - (fixed.size - 1)
        given = share(spare, needs(flexible))
        fixed.to_h { |c, w| [c, w || given.fetch(c)] }
      end

      # Each flexible column's need: its header (plus the sort marker) or its widest cell, in one pass over lines.
      def needs(cols)
        need = cols.to_h { |c| [c, c.label.length + 1] }
        return need if cols.empty?

        @lines.each do |line|
          cols.each do |c|
            n = cell_need(line, c)
            need[c] = n if n > need[c]
          end
        end
        need
      end

      # Splits `spare` between columns by need. If every need fits, each gets its need and the leftover is
      # shared equally; otherwise water-fill: columns needing less than an equal share get their need, the
      # rest split what remains equally. Remainders go to the leftmost columns; never below 1.
      def share(spare, need)
        cols = need.keys
        return {} if cols.empty?

        if need.values.sum <= spare
          return even(spare - need.values.sum, cols).to_h { |c, extra| [c, need[c] + extra] }
        end

        given = {}
        rest = cols.sort_by.with_index { |c, i| [need[c], i] }
        left = spare
        while (c = rest.first) && need[c] <= left / rest.size
          given[c] = need[c]
          left -= need[c]
          rest.shift
        end
        even(left, cols & rest).each { |c, w| given[c] = [w, 1].max }
        cols.to_h { |c| [c, given.fetch(c)] }
      end

      # `amount` split equally across `cols` (leftmost get the remainder), as [[col, width], ...].
      def even(amount, cols)
        return [] if cols.empty?

        base, extra = amount.divmod(cols.size)
        cols.each_with_index.map { |c, i| [c, base + (i < extra ? 1 : 0)] }
      end

      def draw_footer(canvas, rect)
        text = " #{@state.selected + 1}/#{@lines.size} "
        canvas.write(rect.x + rect.width - text.length, rect.bottom, text, :muted)
      end

      def fit(text, width, from)
        return text if text.length <= width
        return text[0, width] if width < 2

        from == :left ? "…#{text[-(width - 1)..]}" : "#{text[0, width - 1]}…"
      end

      def align(text, width, side) = side == :right ? text.rjust(width) : text.ljust(width)
    end
  end
end
