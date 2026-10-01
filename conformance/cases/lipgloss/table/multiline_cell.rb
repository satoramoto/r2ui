# A cell containing a newline makes its row taller.
require "lipgloss"

Lipgloss::Table.new.headers(["A", "B"]).rows([["one\ntwo", "x"], ["y", "z"]]).render
