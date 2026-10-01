# Foreground colour on tree branch connectors.
require "lipgloss"

Lipgloss::Tree.root("R").child("a", "b").enumerator_style(Lipgloss::Style.new.foreground("#FF0000")).render
