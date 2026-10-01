# Styles on outer and inner lists apply independently.
require "lipgloss"

sub = Lipgloss::List.new.items(["x", "y"]).enumerator(:alphabet).item_style(Lipgloss::Style.new.faint(true))
Lipgloss::List.new.items(["a"]).item(sub).items(["b"]).enumerator(:roman).enumerator_style(Lipgloss::Style.new.bold(true)).render
