# frozen_string_literal: true

module R2UI
  module Widgets
    # Dense glyphs for charts and colour helpers. Pure functions returning Strings.
    module Glyphs
      BLANK = 0x2800
      # Braille dot bits per column, from the bottom dot up.
      LEFT = [0x40, 0x04, 0x02, 0x01].freeze
      RIGHT = [0x80, 0x20, 0x10, 0x08].freeze
      # The bits of the bottom `n` dots (n = 0..4) per column, and every braille cell by its bits.
      LEFT_SUMS = (0..4).map { |n| LEFT.first(n).sum }.freeze
      RIGHT_SUMS = (0..4).map { |n| RIGHT.first(n).sum }.freeze
      BRAILLE = Array.new(256) { |bits| (BLANK + bits).chr(Encoding::UTF_8).freeze }.freeze
      PARTIAL = %w[▏ ▎ ▍ ▌ ▋ ▊ ▉].freeze
      HEAT = ["#5FAF5F", "#E5A50A", "#E5484D"].freeze
      HEAT_STEPS = 64

      # stops (frozen copy) => the 65 SGRs of `heat`, one per step; HEAT's table is kept apart so
      # the default needs no hash lookup. Reads take no lock; a miss builds the table outside it.
      @heat_tables = {}
      @heat_default = nil
      # hex => "38;2;r;g;b" / "48;2;r;g;b" (frozen), bounded.
      @fg_cache = {}
      @bg_cache = {}
      SGR_CACHE_LIMIT = 4096
      HEAT_CACHE_LIMIT = 64

      class << self
        # A 24-bit foreground SGR for `fraction` (0..1) across the colour `stops`.
        def heat(fraction, stops: HEAT)
          step = (fraction.to_f.clamp(0.0, 1.0) * HEAT_STEPS).round
          table = stops.equal?(HEAT) ? (@heat_default ||= heat_table(HEAT)) : @heat_tables[stops]
          table ||= begin
            @heat_tables.clear if @heat_tables.size >= HEAT_CACHE_LIMIT
            @heat_tables[stops.map { |s| s.dup.freeze }.freeze] = heat_table(stops)
          end
          table[step]
        end

        def fg(hex) = @fg_cache[hex] || remember(@fg_cache, hex, "38;2;#{Motion.rgb(hex).join(";")}")

        def bg(hex) = @bg_cache[hex] || remember(@bg_cache, hex, "48;2;#{Motion.rgb(hex).join(";")}")

        private

        # Dots (0..4) a braille_line sample fills.
        def line_level(value, top, baseline)
          if value <= 0 then baseline ? 1 : 0
          else ((value / top) * 4).round.clamp(1, 4)
          end
        end

        def heat_table(stops)
          Array.new(HEAT_STEPS + 1) { |step| fg(gradient(stops, step / HEAT_STEPS.to_f)) }.freeze
        end

        def remember(cache, key, value)
          cache.clear if cache.size >= SGR_CACHE_LIMIT
          cache[key] = value.freeze
        end
      end

      module_function

      # One line of braille, exactly `width` cells, 2 samples per cell, newest at the right.
      # Each sample fills 1..4 dots from the bottom; zero shows the bottom dot when `baseline`.
      # (Walks `values` in place, without building a window: it is drawn for every row, every frame.)
      def braille_line(values, width, max: nil, baseline: true)
        return "" if width <= 0

        start = [values.size - (width * 2), 0].max
        top = max
        unless top
          (start...values.size).each do |i|
            v = values[i].to_f
            top = v if top.nil? || v > top
          end
        end
        top = top.nil? || top <= 0 ? 1.0 : top.to_f
        pad = (width * 2) - (values.size - start) # samples missing on the left
        out = String.new(capacity: width * 3, encoding: Encoding::UTF_8)
        width.times do |cell|
          left = (cell * 2) - pad
          right = left + 1
          bits = 0
          bits |= LEFT_SUMS[line_level(values[start + left].to_f, top, baseline)] if left >= 0
          bits |= RIGHT_SUMS[line_level(values[start + right].to_f, top, baseline)] if right >= 0
          out << BRAILLE[bits]
        end
        out
      end

      # A filled area chart: `height` lines of `width` braille cells, 4 * height levels tall,
      # 2 samples per cell, newest at the right.
      def braille_area(values, width, height, max: nil)
        return Array.new([height, 0].max, "") if width <= 0
        return [] if height <= 0

        window = values.last(width * 2).map(&:to_f)
        top = scale(window, max)
        total = height * 4
        levels = window.map { |v| v <= 0 ? 0 : ((v / top) * total).round.clamp(1, total) }
        Array.new(height) do |row|
          from_bottom = height - 1 - row
          cells(levels, width) { |level, dots| dots.first((level - (from_bottom * 4)).clamp(0, 4)).sum }
        end
      end

      # A horizontal bar exactly `width` chars: full blocks, one eighth-precision partial, spaces.
      def bar(fraction, width)
        return "" if width <= 0

        eighths = (fraction.to_f.clamp(0.0, 1.0) * width * 8).round
        full, rest = eighths.divmod(8)
        text = "█" * full
        text += PARTIAL[rest - 1] if rest.positive?
        text.ljust(width)[0, width]
      end

      def paint(text, sgr) = sgr ? "\e[#{sgr}m#{text}\e[0m" : text

      def gradient(stops, t)
        return stops.first if stops.size == 1

        pos = t * (stops.size - 1)
        i = [pos.floor, stops.size - 2].min
        Motion.mix_hex(stops[i], stops[i + 1], pos - i)
      end

      def scale(window, max)
        top = max || window.max
        top.nil? || top <= 0 ? 1.0 : top.to_f
      end

      # Right-aligns the levels into `width` cells (2 per cell, blank padding) and builds each cell
      # from the dots the block picks for each half.
      def cells(levels, width)
        padded = Array.new((width * 2) - levels.size) + levels
        padded.each_slice(2).map do |left, right|
          bits = 0
          bits |= yield(left, LEFT) if left
          bits |= yield(right, RIGHT) if right
          (BLANK + bits).chr(Encoding::UTF_8)
        end.join
      end
    end
  end
end
