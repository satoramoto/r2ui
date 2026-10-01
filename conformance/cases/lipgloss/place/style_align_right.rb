# Style#align_horizontal(:right) with a width right-aligns each line.
require "lipgloss"

Lipgloss::Style.new.width(8).align_horizontal(:right).render("ab\nlonger")
