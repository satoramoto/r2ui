# Rows without headers.
require "lipgloss"

Lipgloss::Table.new.rows([["a", "bb"], ["ccc", "d"]]).render
