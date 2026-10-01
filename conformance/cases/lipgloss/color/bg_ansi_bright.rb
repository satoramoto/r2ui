# ANSI colours 8-15 (bright) as background.
require "lipgloss"

(8..15).map { |n| Lipgloss::Style.new.background(n.to_s).render("x") }.join("|")
