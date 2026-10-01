# Underline style on the root only.
require "lipgloss"

Lipgloss::Tree.root("R").child("a", "b").root_style(Lipgloss::Style.new.underline(true)).render
