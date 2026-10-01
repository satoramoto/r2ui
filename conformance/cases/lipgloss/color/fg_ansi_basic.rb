# ANSI colours 0-7 as foreground.
require "lipgloss"

(0..7).map { |n| Lipgloss::Style.new.foreground(n.to_s).render("x") }.join("|")
