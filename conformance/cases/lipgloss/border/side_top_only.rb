# Only the top border side enabled.
require "lipgloss"

Lipgloss::Style.new.border_style(:normal).border_top(true).render("Box")
