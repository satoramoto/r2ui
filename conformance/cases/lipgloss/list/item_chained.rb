# Items added one at a time with item.
require "lipgloss"

Lipgloss::List.new.item("a").item("b").item("c").render
