# Root, item and enumerator styles together.
require "lipgloss"

Lipgloss::Tree.root("R").child("a", "b").root_style(Lipgloss::Style.new.bold(true).foreground("#FFFF00")).item_style(Lipgloss::Style.new.italic(true)).enumerator_style(Lipgloss::Style.new.foreground("#00FFFF")).render
