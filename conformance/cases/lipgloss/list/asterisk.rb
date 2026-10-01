# Asterisk enumerator.
require "lipgloss"

Lipgloss::List.new.items(["a", "b", "c"]).enumerator(:asterisk).render
