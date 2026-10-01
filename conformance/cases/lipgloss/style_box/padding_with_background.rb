# Padding cells carry the background colour.
require "lipgloss"

Lipgloss::Style.new.padding(1, 2).background("#336699").render("ab")
