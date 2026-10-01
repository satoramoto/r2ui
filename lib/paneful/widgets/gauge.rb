# frozen_string_literal: true

module Paneful
  module Widgets
    # "Used ▕██████░░░░▏ 21G / 32G 67%" on one line.
    module Gauge
      module_function

      def draw(canvas, rect, label:, value:, total:, column:)
        return if rect.empty?

        fraction = total.to_f.positive? ? (value.to_f / total).clamp(0, 1) : 0
        right = "#{column.render(value)} / #{column.render(total)} #{(fraction * 100).round}%"
        label = label.ljust(10)
        bar_w = rect.width - label.length - right.length - 4
        canvas.write(rect.x, rect.y, label, :bold)
        if bar_w >= 4
          filled = (fraction * bar_w).round
          canvas.write(rect.x + label.length, rect.y, "▕", :muted)
          canvas.write(rect.x + label.length + 1, rect.y, "█" * filled, style(fraction))
          canvas.write(rect.x + label.length + 1 + filled, rect.y, "░" * (bar_w - filled), :muted)
          canvas.write(rect.x + label.length + 1 + bar_w, rect.y, "▏", :muted)
        end
        canvas.write(rect.x + rect.width - right.length, rect.y, right)
      end

      def style(fraction)
        if fraction >= 0.9 then :alert
        elsif fraction >= 0.7 then :warn
        else :ok
        end
      end
    end
  end
end
