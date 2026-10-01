# item and items accumulate in order.
require "lipgloss"

Lipgloss::List.new.item("a").items(["b", "c"]).item("d").render
