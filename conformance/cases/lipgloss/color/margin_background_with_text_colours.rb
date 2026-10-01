# Text background and margin background stay distinct.
require "lipgloss"

Lipgloss::Style.new.background("#aa0000").margin_left(2).margin_background("#0000aa").render("M")
