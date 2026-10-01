# Distinct background on each border side.
require "lipgloss"

Lipgloss::Style.new.border(:normal).border_top_background("#FF0000").border_right_background("#00FF00").border_bottom_background("#0000FF").border_left_background("#FFFF00").render("Box")
