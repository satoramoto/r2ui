# child accepts several children at once.
require "lipgloss"

Lipgloss::Tree.root("Project").child("src", "lib", "test").render
