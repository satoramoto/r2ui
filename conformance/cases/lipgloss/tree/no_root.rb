# A tree with children but no root.
require "lipgloss"

Lipgloss::Tree.new.child("a").child("b").render
