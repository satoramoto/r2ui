# Distinct foreground on each border side.
require "lipgloss"

Lipgloss::Style.new.border(:normal).border_top_foreground("#FF0000").border_right_foreground("#00FF00").border_bottom_foreground("#0000FF").border_left_foreground("#FFFF00").render("Box")
