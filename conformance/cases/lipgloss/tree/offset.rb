# offset(1, 1) hides the first and last child.
require "lipgloss"

Lipgloss::Tree.root("R").child("a", "b", "c", "d").offset(1, 1).render
