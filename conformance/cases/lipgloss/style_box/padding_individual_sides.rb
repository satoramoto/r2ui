# padding_top/right/bottom/left set each side separately.
require "lipgloss"

Lipgloss::Style.new.padding_top(2).padding_right(1).padding_bottom(0).padding_left(3).render("ab")
