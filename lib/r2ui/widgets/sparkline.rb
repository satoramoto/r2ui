# frozen_string_literal: true

module R2UI
  module Widgets
    module Sparkline
      BARS = %w[▁ ▂ ▃ ▄ ▅ ▆ ▇ █].freeze
      # Eighths of a full cell, for multi-line charts.
      BLOCKS = [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"].freeze

      module_function

      # One line of bars for the newest `width` values, scaled to the window's max (or `max:`).
      def line(values, width, max: nil)
        window = values.last(width).map(&:to_f)
        return "" if window.empty?

        top = max || window.max
        top = 1.0 if top.nil? || top <= 0
        window.map { |v| BARS[((v / top) * (BARS.size - 1)).round.clamp(0, BARS.size - 1)] }.join
      end

      # A chart `rect.height` lines tall, newest value at the right edge.
      def draw(canvas, rect, values, max: nil, style: :ok)
        return if rect.empty?

        window = values.last(rect.width).map(&:to_f)
        top = max || window.max
        top = 1.0 if top.nil? || top <= 0
        offset = rect.width - window.size
        window.each_with_index do |v, i|
          eighths = ((v / top).clamp(0, 1) * rect.height * 8).round
          rect.height.times do |row|
            fill = (eighths - (row * 8)).clamp(0, 8)
            next if fill.zero?

            canvas.write(rect.x + offset + i, rect.bottom - 1 - row, BLOCKS[fill], style)
          end
        end
      end
    end
  end
end
