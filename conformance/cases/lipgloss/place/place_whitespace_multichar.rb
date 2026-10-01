# place with a multi-character whitespace_chars pattern cycles through it.
require "lipgloss"

Lipgloss.place(11, 3, :left, :top, "ab", whitespace_chars: "-=")
