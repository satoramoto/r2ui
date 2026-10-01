# Three levels of subtrees.
require "lipgloss"

c = Lipgloss::Tree.root("c").child("leaf")
b = Lipgloss::Tree.root("b").child(c).child("b2")
Lipgloss::Tree.root("a").child(b).child("a2").render
