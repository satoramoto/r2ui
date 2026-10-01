# join_vertical with an empty-string block and a single block.
require "lipgloss"

[Lipgloss.join_vertical(:left, "ab", "", "c"), Lipgloss.join_vertical(:center, "a\nlong")].join("\n--\n")
