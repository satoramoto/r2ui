# Hidden border keeps spacing but draws no lines.
require "lipgloss"

Lipgloss::Table.new.border(:hidden).headers(["A", "B"]).rows([["1", "2"], ["3", "4"]]).render
