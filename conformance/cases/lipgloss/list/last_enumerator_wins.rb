# Calling enumerator twice keeps the last one.
require "lipgloss"

Lipgloss::List.new.items(["a", "b"]).enumerator(:dash).enumerator(:arabic).render
