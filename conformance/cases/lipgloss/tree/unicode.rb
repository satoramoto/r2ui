# Wide and accented characters in a tree.
require "lipgloss"

Lipgloss::Tree.root("日本").child("café").child("naïve").render
