# border_header(false) drops the line under the header.
require "lipgloss"

Lipgloss::Table.new.border_header(false).headers(["A", "B"]).rows([["1", "2"]]).render
