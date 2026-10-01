# style_func colours one column's data cells.
require "lipgloss"

Lipgloss::Table.new.headers(["A", "B"]).rows([["1", "2"], ["3", "4"]])
  .style_func(rows: 2, columns: 2) do |row, col|
    row >= 0 && col == 1 ? Lipgloss::Style.new.foreground("#00FF00") : nil
  end.render
