# Tree.new with a root string.
require "lipgloss"

Lipgloss::Tree.new("Project").child("a").child("b").render
