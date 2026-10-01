# place with a box smaller than the content returns the content unchanged.
require "lipgloss"

Lipgloss.place(2, 1, :center, :center, "abcd\nefgh")
