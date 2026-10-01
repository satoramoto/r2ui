# wrap(false) with a narrow width truncates instead of wrapping.
require "lipgloss"

Lipgloss::Table.new.width(24).wrap(false).headers(["Name", "Notes"])
  .rows([["Alice", "likes long walks on the beach"], ["Bob", "short"]]).render
