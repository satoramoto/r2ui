# join_horizontal with an empty-string block between two blocks.
require "lipgloss"

Lipgloss.join_horizontal(:top, "a\nb", "", "c")
