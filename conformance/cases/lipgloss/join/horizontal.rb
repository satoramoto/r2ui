# Joining blocks of different heights side by side, aligned to the top.
require "lipgloss"

left = Lipgloss::Style.new.background("#3C3C3C").padding(0, 1).render("a\nb\nc")
right = Lipgloss::Style.new.foreground("#04B575").render("one\ntwo")
Lipgloss.join_horizontal(:top, left, " ", right)
