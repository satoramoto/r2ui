# Rounded enumerator on a tree with a subtree.
require "lipgloss"

sub = Lipgloss::Tree.root("sub").child("x").child("y").enumerator(:rounded)
Lipgloss::Tree.root("top").child(sub).child("z").enumerator(:rounded).render
