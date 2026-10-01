# join_horizontal with a single block still pads ragged lines.
require "lipgloss"

Lipgloss.join_horizontal(:top, "a\nlong\nb")
