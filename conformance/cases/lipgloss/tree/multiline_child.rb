# A multi-line child keeps its branch line alongside.
require "lipgloss"

Lipgloss::Tree.root("R").child("one
two").child("three").render
