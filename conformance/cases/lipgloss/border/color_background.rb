# border_background sets a background on all sides.
require "lipgloss"

Lipgloss::Style.new.border(:normal).border_background("#0000FF").render("Box")
