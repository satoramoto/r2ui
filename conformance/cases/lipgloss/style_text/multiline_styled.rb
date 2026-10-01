# Styling applies to each line of a multi-line string.
require "lipgloss"

Lipgloss::Style.new.bold(true).foreground("#FF8700").render("one\ntwo\nthree")
