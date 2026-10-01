# Dash enumerator.
require "lipgloss"

Lipgloss::List.new.items(["a", "b", "c"]).enumerator(:dash).render
