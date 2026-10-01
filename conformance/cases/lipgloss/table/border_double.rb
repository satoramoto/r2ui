# Double border style.
require "lipgloss"

Lipgloss::Table.new.border(:double).headers(["A", "B"]).rows([["1", "2"], ["3", "4"]]).render
