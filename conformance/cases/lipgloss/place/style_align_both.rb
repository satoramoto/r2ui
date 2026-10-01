# Style#align(h, v) with width and height, fractional horizontal.
require "lipgloss"

Lipgloss::Style.new.width(10).height(4).align(0.25, :center).render("ab\ncd")
