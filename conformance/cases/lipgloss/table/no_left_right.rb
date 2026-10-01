# border_left(false) and border_right(false) only.
require "lipgloss"

Lipgloss::Table.new.border_left(false).border_right(false).headers(["A", "B"]).rows([["1", "2"]]).render
