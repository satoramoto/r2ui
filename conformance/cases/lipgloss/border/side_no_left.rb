# Border with only the left side switched off.
require "lipgloss"

Lipgloss::Style.new.border(:normal).border_left(false).render("Box")
