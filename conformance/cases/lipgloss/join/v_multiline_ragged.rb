# join_vertical pads every line of multi-line blocks to the overall max width.
require "lipgloss"

Lipgloss.join_vertical(:left, "a\nbbb", "cc\nd")
