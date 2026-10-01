# A rounded border around padded, two-line content, with a coloured border.
require "lipgloss"

Lipgloss::Style.new
  .border(:rounded)
  .border_foreground("#7D56F4")
  .padding(1, 2)
  .render("Hello,\nlipgloss")
