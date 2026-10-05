# frozen_string_literal: true

module R2UI
  module Widgets
    # Dense glyphs for charts and colour helpers. Pure functions returning Strings.
    module Glyphs
      BLANK = 0x2800
      # Braille dot bits per column, from the bottom dot up.
      LEFT = [0x40, 0x04, 0x02, 0x01].freeze
      RIGHT = [0x80, 0x20, 0x10, 0x08].freeze
      PARTIAL = %w[▏ ▎ ▍ ▌ ▋ ▊ ▉].freeze
      HEAT = ["#5FAF5F", "#E5A50A", "#E5484D"].freeze

      @heat_cache = {}
      @heat_lock = Mutex.new

      module_function

      # One line of braille, exactly `width` cells, 2 samples per cell, newest at the right.
      # Each sample fills 1..4 dots from the bottom; zero shows the bottom dot when `baseline`.
      def braille_line(values, width, max: nil, baseline: true)
        return "" if width <= 0

        window = values.last(width * 2).map(&:to_f)
        top = scale(window, max)
        levels = window.map do |v|
          if v <= 0 then baseline ? 1 : 0
          else ((v / top) * 4).round.clamp(1, 4)
          end
        end
        cells(levels, width) { |level, dots| dots.first(level).sum }
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

      # A 24-bit foreground SGR for `fraction` (0..1) across the colour `stops`.
      def heat(fraction, stops: HEAT)
        step = (fraction.to_f.clamp(0.0, 1.0) * 64).round
        key = [stops, step]
        cached = @heat_lock.synchronize { @heat_cache[key] }
        return cached if cached

        sgr = fg(gradient(stops, step / 64.0))
        @heat_lock.synchronize { @heat_cache[key] = sgr }
      end

      def fg(hex) = "38;2;#{Motion.rgb(hex).join(";")}"

      def bg(hex) = "48;2;#{Motion.rgb(hex).join(";")}"

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
