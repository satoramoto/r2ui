# Root with three string children.
require "lipgloss"

Lipgloss::Tree.root("Project").child("src").child("lib").child("test").render
