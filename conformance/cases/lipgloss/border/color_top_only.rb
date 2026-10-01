# Foreground on the top side only; others uncoloured.
require "lipgloss"

Lipgloss::Style.new.border(:normal).border_top_foreground("#FF8700").render("Box")
