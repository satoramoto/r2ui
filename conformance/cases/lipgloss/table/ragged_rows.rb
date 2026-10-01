# Rows with fewer cells than the header are padded out.
require "lipgloss"

Lipgloss::Table.new.headers(["A", "B", "C"]).rows([["1"], ["1", "2", "3"], ["1", "2"]]).render
