# height smaller than content cuts off rows.
require "lipgloss"

Lipgloss::Table.new.height(5).headers(["A"]).rows([["1"], ["2"], ["3"], ["4"], ["5"]]).render
