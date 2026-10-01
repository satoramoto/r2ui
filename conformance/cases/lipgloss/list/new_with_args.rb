# List.new accepts the items directly.
require "lipgloss"

Lipgloss::List.new("x", "y", "z").enumerator(:arabic).render
