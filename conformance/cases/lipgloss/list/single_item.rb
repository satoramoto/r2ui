# A one-item list.
require "lipgloss"

Lipgloss::List.new.items(["only"]).enumerator(:arabic).render
