# join_horizontal pads by display width for double-width characters.
require "lipgloss"

Lipgloss.join_horizontal(:top, "日本\nab", "|")
