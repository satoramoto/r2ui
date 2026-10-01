# Enumerator style with right padding widens the marker gap.
require "lipgloss"

Lipgloss::List.new.items(["a", "b"]).enumerator(:dash).enumerator_style(Lipgloss::Style.new.padding_right(2)).render
