# style_func padding widens each cell.
require "lipgloss"

Lipgloss::Table.new.headers(["A", "B"]).rows([["1", "2"]])
  .style_func(rows: 1, columns: 2) { |_r, _c| Lipgloss::Style.new.padding(0, 1) }.render
