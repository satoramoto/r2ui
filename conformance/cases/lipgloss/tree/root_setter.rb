# root= returns a tree with the new root.
require "lipgloss"

t = Lipgloss::Tree.new.child("a").child("b")
t.send(:root=, "Top").render
