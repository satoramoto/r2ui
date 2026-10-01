# width smaller than content shrinks columns and wraps text.
require "lipgloss"

Lipgloss::Table.new.width(24).headers(["Name", "Notes"])
  .rows([["Alice", "likes long walks on the beach"], ["Bob", "short"]]).render
