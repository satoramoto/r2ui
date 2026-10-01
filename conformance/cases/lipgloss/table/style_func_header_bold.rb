# style_func styles only the header row via HEADER_ROW.
require "lipgloss"

Lipgloss::Table.new.headers(["A", "B"]).rows([["1", "2"]])
  .style_func(rows: 1, columns: 2) do |row, _col|
    row == Lipgloss::Table::HEADER_ROW ? Lipgloss::Style.new.bold(true) : nil
  end.render
