# Only the left border side enabled.
require "lipgloss"

Lipgloss::Style.new.border_style(:normal).border_left(true).render("Box")
