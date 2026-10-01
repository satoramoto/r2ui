# margin_background colours the margin cells.
require "lipgloss"

Lipgloss::Style.new.margin(1, 2).margin_background("#AA3300").render("ab")
