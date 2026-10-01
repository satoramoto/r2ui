# Arabic numeral enumerator.
require "lipgloss"

Lipgloss::List.new.items(["one", "two", "three"]).enumerator(:arabic).render
