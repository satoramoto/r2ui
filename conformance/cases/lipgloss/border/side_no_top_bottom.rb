# Border with top and bottom switched off leaves left and right.
require "lipgloss"

Lipgloss::Style.new.border(:rounded).border_top(false).border_bottom(false).render("Box")
