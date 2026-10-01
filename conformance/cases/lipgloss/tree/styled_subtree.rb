# A subtree keeps its own styles inside a plain parent.
require "lipgloss"

sub = Lipgloss::Tree.root("sub").child("x").item_style(Lipgloss::Style.new.bold(true))
Lipgloss::Tree.root("R").child(sub).child("y").render
