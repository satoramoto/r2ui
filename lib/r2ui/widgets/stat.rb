# frozen_string_literal: true

module R2UI
  module Widgets
    # Label on the left, formatted value on the right, one per line.
    module Stat
      module_function

      def draw(canvas, rect, pairs)
        pairs.first(rect.height).each_with_index do |(column, value), i|
          text = column.render(value)
          canvas.write(rect.x, rect.y + i, column.label, :muted, max: rect.width - text.length - 1)
          canvas.write(rect.x + rect.width - text.length, rect.y + i, text, :bold)
        end
      end
    end
  end
end
