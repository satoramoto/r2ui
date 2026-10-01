# border_top(false) and border_bottom(false) only.
require "lipgloss"

Lipgloss::Table.new.border_top(false).border_bottom(false).headers(["A", "B"]).rows([["1", "2"]]).render
