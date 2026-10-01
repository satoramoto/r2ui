# Colours combined with bold and underline attributes.
require "lipgloss"

Lipgloss::Style.new.bold(true).underline(true).foreground("#00ffcc").background("5").render("mix")
