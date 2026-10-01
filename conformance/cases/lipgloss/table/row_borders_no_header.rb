# border_row(true) on a table without headers.
require "lipgloss"

Lipgloss::Table.new.border_row(true).rows([["1", "2"], ["3", "4"]]).render
