# width larger than content stretches the table.
require "lipgloss"

Lipgloss::Table.new.width(30).headers(["A", "B"]).rows([["1", "2"], ["3", "4"]]).render
