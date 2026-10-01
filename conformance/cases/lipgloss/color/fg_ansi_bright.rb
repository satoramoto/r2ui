# ANSI colours 8-15 (bright) as foreground.
require "lipgloss"

(8..15).map { |n| Lipgloss::Style.new.foreground(n.to_s).render("x") }.join("|")
