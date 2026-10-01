# align_vertical(:bottom) pushes text to the bottom of the height.
require "lipgloss"

Lipgloss::Style.new.height(4).align_vertical(:bottom).render("ab")
