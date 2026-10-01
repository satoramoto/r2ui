# frozen_string_literal: true

module R2UI
  module Widgets
    # A bordered panel with a title on the top edge. Returns the inner rect.
    module Box
      module_function

      def draw(canvas, rect, title: nil, focused: false, tabs: [])
        return rect if rect.width < 2 || rect.height < 2

        style = focused ? :focus : :border
        right = rect.x + rect.width - 1
        canvas.write(rect.x, rect.y, "╭#{"─" * (rect.width - 2)}╮", style)
        (rect.height - 2).times do |i|
          canvas.write(rect.x, rect.y + 1 + i, "│", style)
          canvas.write(right, rect.y + 1 + i, "│", style)
        end
        canvas.write(rect.x, rect.bottom - 1, "╰#{"─" * (rect.width - 2)}╯", style)

        x = rect.x + 2
        max = right - 1
        if title
          canvas.write(x, rect.y, " #{title} ", :title, max: max - x)
          x += title.length + 3
        end
        tabs.each do |label, active|
          break if x >= max

          canvas.write(x, rect.y, active ? "[#{label}]" : " #{label} ", active ? :accent : :muted, max: max - x)
          x += label.length + 2
        end
        rect.inner
      end
    end
  end
end
