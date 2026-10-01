# place_vertical at top and bottom; added rows are padded to the block width.
require "lipgloss"

[Lipgloss.place_vertical(4, :top, "ab\ncd"), Lipgloss.place_vertical(4, :bottom, "ab\ncd")].join("\n--\n")
