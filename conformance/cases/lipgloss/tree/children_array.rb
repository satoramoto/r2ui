# children takes an array of strings.
require "lipgloss"

Lipgloss::Tree.root("Project").children(["src", "lib"]).render
