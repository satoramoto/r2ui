# ANSI colours 0-7 as background.
require "lipgloss"

(0..7).map { |n| Lipgloss::Style.new.background(n.to_s).render("x") }.join("|")
