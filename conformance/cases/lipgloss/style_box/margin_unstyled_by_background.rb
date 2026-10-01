# A background colour does not colour the margin (only margin_background does).
require "lipgloss"

Lipgloss::Style.new.margin(1).background("#336699").render("ab")
