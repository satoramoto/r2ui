# CJK double-width content is measured by cell width.
require "lipgloss"

Lipgloss::Table.new.headers(["名前", "Name"]).rows([["日本語", "x"], ["a", "yy"]]).render
