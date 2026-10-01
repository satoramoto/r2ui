# row adds one row at a time, in order.
require "lipgloss"

Lipgloss::Table.new.headers(["K", "V"]).row(["a", "1"]).row(["b", "2"]).render
