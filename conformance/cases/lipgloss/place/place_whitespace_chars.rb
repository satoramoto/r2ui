# place with whitespace_chars fills the surround with that character.
require "lipgloss"

Lipgloss.place(9, 5, :center, :center, "ab\ncd", whitespace_chars: ".")
