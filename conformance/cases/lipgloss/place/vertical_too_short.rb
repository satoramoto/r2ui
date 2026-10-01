# place_vertical with height <= content height leaves the text unchanged.
require "lipgloss"

Lipgloss.place_vertical(1, :center, "ab\ncd")
