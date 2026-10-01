# Bold item text only.
require "lipgloss"

Lipgloss::List.new.items(["Red", "Green"]).item_style(Lipgloss::Style.new.bold(true)).render
