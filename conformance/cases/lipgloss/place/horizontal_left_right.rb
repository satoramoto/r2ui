# place_horizontal at left and right.
require "lipgloss"

[Lipgloss.place_horizontal(6, :left, "ab\ncd"), Lipgloss.place_horizontal(6, :right, "ab\ncd")].join("\n--\n")
