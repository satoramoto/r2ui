# place_horizontal with width <= content width leaves the text unchanged.
require "lipgloss"

Lipgloss.place_horizontal(2, :center, "abcd\nef")
