# Bold style on child items.
require "lipgloss"

Lipgloss::Tree.root("R").child("a", "b").item_style(Lipgloss::Style.new.bold(true)).render
