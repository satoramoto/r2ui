# frozen_string_literal: true

module R2UI
  module Widgets
    # The index table: header, sort marker, grouped/tree labels, inline sparklines, selection.
    # With a `motion`, a 1-cell gutter on the left marks lines that moved (▴/▾) or are new (•).
    class Table
      SPARK_WIDTH = 10
      BRAILLE_WIDTH = 5
      MIN_TEXT = 8
      MARKS = { up: "▴", down: "▾", new: "•" }.freeze
      MARK_SECONDS = { up: 1.5, down: 1.5, new: 2.0 }.freeze
      MARK_FROM = "#D97757"
      MARK_TO = "#555555"

      # `spark` is called with (line, column) and returns that line's recent values. `motion` (an
      # R2UI::Motion) turns on the gutter marks; `motion_key` tells tables sharing a Motion apart.
      # `columns` (Column objects) draws only those, in that order; default all of the resource's.
      def initialize(resource, lines, state:, focused:, label_key: nil, spark: nil, motion: nil, motion_key: nil,
                     columns: nil)
        @resource = resource
        @columns = columns || resource.columns
        @lines = lines
        @state = state
        @focused = focused
        @spark = spark
        @motion = motion
        @motion_key = motion_key || state.object_id
        label_key = nil if label_key && @columns.none? { |c| c.key == label_key }
        @label_key = label_key || @columns.find { |c| !c.numeric? && c.format != :id }&.key
      end

      def draw(canvas, rect)
        return if rect.empty?

        gutter = @motion ? 1 : 0
        marks = @motion ? gutter_marks : {}
        cols = rect.with(x: rect.x + gutter, width: rect.width - gutter)
        layout = widths(cols.width)
        draw_header(canvas, cols, layout)
        body = rect.with(y: rect.y + 1, height: rect.height - 1)
        @state.scroll_to_selection(body.height, @lines.size)
        @lines.drop(@state.offset).first(body.height).each_with_index do |line, i|
          index = @state.offset + i
          selected = @focused && index == @state.selected
          canvas.fill(body.with(y: body.y + i, height: 1), " ", :selected) if selected
          draw_line(canvas, cols.x, body.y + i, line, layout, selected)
          mark = marks[line.id]
          canvas.write(rect.x, body.y + i, mark[0], mark[1]) if mark
        end
        draw_footer(canvas, rect) if @lines.size > body.height
      end

      private

      # {line id => [glyph, sgr]} for lines whose move/new mark is still fading. Keeps the motion
      # active while any mark shows.
      def gutter_marks
        @state.track_positions(@lines)
        hold = 0.0
        marks = {}
        @lines.each_with_index do |line, i|
          elapsed = @motion.age([:r2ui_table, @motion_key, line.id], i)
          kind = @state.marks[line.id]
          next unless kind

          left = MARK_SECONDS[kind] - elapsed
          if left <= 0 || !@motion.enabled
            @state.marks.delete(line.id)
            next
          end
          hold = left if left > hold
          colour = Motion.mix_hex(MARK_FROM, MARK_TO, elapsed / MARK_SECONDS[kind])
          marks[line.id] = [MARKS[kind], Glyphs.fg(colour)]
        end
        @motion.hold(hold) if hold.positive?
        marks
      end

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
          at = x
          cell(line, col, w).each do |text, style|
            left = x + w - at
            break if left <= 0

            canvas.write(at, y, text, selected ? :selected : style, max: left)
            at += text.length
          end
          x += w + 1
        end
      end

      # [[text, style], ...] segments filling the cell.
      def cell(line, col, width)
        if col.key == @label_key && (line.label || line.depth.positive? || line.expandable?)
          prefix, body, suffix = label_parts(line, col)
          body = fit(body, [width - prefix.length - suffix.length, 1].max, Format.truncate_from(col.format))
          return [[fit("#{prefix}#{body}#{suffix}", width, :right), line.label ? :bold : :plain]]
        end

        value = line.values[col.key]
        value = "×#{line.count}" if col.aggregate == :count && line.label
        text = value.is_a?(String) && col.aggregate == :count ? value : col.render(value)
        return spark_cell(line, col, width, value, text) if col.sparkline && @spark

        [[align(fit(text, width, Format.truncate_from(col.format)), width, col.align),
          custom_style(col, value, line) || style_for(col, value)]]
      end

      # The sparkline and the number, each in its own style.
      def spark_cell(line, col, width, value, text)
        values = @spark.call(line, col)
        spark_w = spark_width(col)
        if col.sparkline == :braille
          # Fewer than 2 samples have no shape yet: baseline dots only, never a full column.
          chart = Glyphs.braille_line(values.size < 2 ? values.map { 0 } : values, spark_w, max: col.spark_max)
          default = :accent
        else
          chart = Sparkline.line(values, spark_w, max: col.spark_max).rjust(spark_w)
          default = :plain
        end
        spark_style = col.spark_style.respond_to?(:call) ? col.spark_style.call(values, line) : col.spark_style
        text_w = width - spark_w - 1
        [[chart, spark_style || default], [" ", :plain],
         [align(text, text_w, col.align), custom_style(col, value, line) || :plain]]
      end

      def custom_style(col, value, line) = col.style&.call(value, line)

      def spark_width(col) = col.spark_width || (col.sparkline == :braille ? BRAILLE_WIDTH : SPARK_WIDTH)

      # [indent and tree marker, the value (truncated to fit), count suffix]
      def label_parts(line, col)
        if line.label
          body = Format.call(col.format, line.label)
          counted = @columns.any? { |c| c.aggregate == :count }
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

      # Fixed-width columns get their width; text columns share the rest. Drops columns that don't
      # fit: the lowest priority first, the last declared among equals.
      def widths(total)
        fixed = @columns.to_h do |c|
          w = c.width || Format.default_width(c.format)
          w &&= [w, c.label.length + 1].max
          w += spark_width(c) + 1 if w && c.sparkline
          [c, w]
        end
        loop do
          flexible = fixed.count { |_, w| w.nil? }
          used = fixed.values.compact.sum + fixed.size - 1
          spare = total - used
          break if flexible.zero? ? spare >= 0 : spare >= flexible * MIN_TEXT
          break if fixed.size == 1

          fixed.delete(fixed.keys.reverse.min_by { |c| c.priority || 0 })
        end
        flexible = fixed.count { |_, w| w.nil? }
        spare = total - fixed.values.compact.sum - (fixed.size - 1)
        fixed.to_h { |c, w| [c, w || [spare / [flexible, 1].max, 1].max] }
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
