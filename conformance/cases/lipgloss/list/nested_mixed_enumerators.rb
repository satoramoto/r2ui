# Outer arabic list with an inner dash list.
require "lipgloss"

sub = Lipgloss::List.new.items(["x", "y"]).enumerator(:dash)
Lipgloss::List.new.items(["a"]).item(sub).items(["b"]).enumerator(:arabic).render
