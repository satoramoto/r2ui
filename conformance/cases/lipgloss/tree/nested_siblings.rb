# Two subtrees side by side.
require "lipgloss"

a = Lipgloss::Tree.root("a").child("a1").child("a2")
b = Lipgloss::Tree.root("b").child("b1")
Lipgloss::Tree.root("Project").child(a).child(b).render
