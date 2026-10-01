# style_func alternating background on even and odd rows.
require "lipgloss"

Lipgloss::Table.new.headers(["A"]).rows([["1"], ["2"], ["3"]])
  .style_func(rows: 3, columns: 1) do |row, _c|
    next nil if row < 0
    Lipgloss::Style.new.background(row.even? ? "#333333" : "#555555")
  end.render
