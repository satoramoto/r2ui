# border_column(false) drops the vertical separators between columns.
require "lipgloss"

Lipgloss::Table.new.border_column(false).headers(["A", "B"]).rows([["1", "2"]]).render
