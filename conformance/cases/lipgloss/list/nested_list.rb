# A sub-list added with item is nested under the preceding item.
require "lipgloss"

sub = Lipgloss::List.new.items(["x", "y"])
Lipgloss::List.new.item("a").item(sub).item("b").render
