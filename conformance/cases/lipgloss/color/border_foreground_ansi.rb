# border_foreground with an ANSI index.
require "lipgloss"

Lipgloss::Style.new.border(:normal).border_foreground("9").render("Box")
