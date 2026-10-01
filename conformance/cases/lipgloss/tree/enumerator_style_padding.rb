# Enumerator style padding widens the connector.
require "lipgloss"

Lipgloss::Tree.root("R").child("a", "b").enumerator_style(Lipgloss::Style.new.padding_right(2)).render
