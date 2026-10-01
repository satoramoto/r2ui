# A list with no enumerator call uses the default.
require "lipgloss"

Lipgloss::List.new.items(["a", "b", "c"]).render
