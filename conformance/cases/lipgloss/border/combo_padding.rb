# Border outside padding on all sides.
require "lipgloss"

Lipgloss::Style.new.border(:normal).padding(1, 3).render("Box")
