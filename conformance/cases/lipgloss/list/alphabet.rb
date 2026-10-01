# Alphabet enumerator.
require "lipgloss"

Lipgloss::List.new.items(["one", "two", "three"]).enumerator(:alphabet).render
