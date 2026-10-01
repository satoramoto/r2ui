# border_style colours the border lines.
require "lipgloss"

Lipgloss::Table.new
  .border_style(Lipgloss::Style.new.foreground("#FF8700"))
  .headers(["A", "B"]).rows([["1", "2"]]).render
