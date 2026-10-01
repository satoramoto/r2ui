# border_top/bottom/left/right(false) remove all outer edges.
require "lipgloss"

Lipgloss::Table.new
  .border_top(false).border_bottom(false).border_left(false).border_right(false)
  .headers(["A", "B"]).rows([["1", "2"], ["3", "4"]]).render
