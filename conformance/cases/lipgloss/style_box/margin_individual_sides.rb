# margin_top/right/bottom/left set each side separately.
require "lipgloss"

Lipgloss::Style.new.margin_top(1).margin_right(2).margin_bottom(0).margin_left(3).render("ab")
