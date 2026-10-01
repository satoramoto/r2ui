# Markdown border style.
require "lipgloss"

Lipgloss::Table.new.border(:markdown).headers(["A", "B"]).rows([["1", "2"], ["3", "4"]]).render
