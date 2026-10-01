# offset skips leading data rows.
require "lipgloss"

Lipgloss::Table.new.offset(2).headers(["A"]).rows([["1"], ["2"], ["3"], ["4"]]).render
