# Border foreground and background combined.
require "lipgloss"

Lipgloss::Style.new.border(:double).border_foreground("#00ff00").border_background("#000080").render("Box")
