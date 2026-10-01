# Default bullet enumerator on a three-item list.
require "lipgloss"

Lipgloss::List.new.items(["a", "b", "c"]).enumerator(:bullet).render
