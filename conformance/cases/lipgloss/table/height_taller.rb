# height larger than content leaves the table at its natural height.
require "lipgloss"

Lipgloss::Table.new.height(10).headers(["A", "B"]).rows([["1", "2"], ["3", "4"]]).render
