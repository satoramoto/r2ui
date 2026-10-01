# style_func right-aligns a column with an explicit width.
require "lipgloss"

Lipgloss::Table.new.headers(["Item", "Qty"]).rows([["apple", "3"], ["fig", "12"]])
  .style_func(rows: 2, columns: 2) do |_r, col|
    col == 1 ? Lipgloss::Style.new.width(6).align(:right) : nil
  end.render
