# border_row(true) draws a line between every row.
require "lipgloss"

Lipgloss::Table.new.border_row(true).headers(["A", "B"]).rows([["1", "2"], ["3", "4"], ["5", "6"]]).render
