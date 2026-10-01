# Wide and accented characters in items.
require "lipgloss"

Lipgloss::List.new.items(["café", "日本語", "x"]).render
