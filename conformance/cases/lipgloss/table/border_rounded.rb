# Rounded border style.
require "lipgloss"

Lipgloss::Table.new.border(:rounded).headers(["A", "B"]).rows([["1", "2"], ["3", "4"]]).render
