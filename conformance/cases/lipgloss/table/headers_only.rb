# Headers with no rows.
require "lipgloss"

Lipgloss::Table.new.headers(["One", "Two"]).render
