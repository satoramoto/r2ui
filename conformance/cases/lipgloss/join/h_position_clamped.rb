# join_horizontal with positions outside 0..1 are clamped (-1 acts as top, 2 acts as bottom).
require "lipgloss"

[Lipgloss.join_horizontal(-1.0, "a\nb\nc", "xy"), Lipgloss.join_horizontal(2.0, "a\nb\nc", "xy")].join("\n--\n")
