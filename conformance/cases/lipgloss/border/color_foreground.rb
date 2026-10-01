# border_foreground colours all sides.
require "lipgloss"

Lipgloss::Style.new.border(:normal).border_foreground("#FF0000").render("Box")
