# width word-wraps text longer than the width.
require "lipgloss"

Lipgloss::Style.new.width(10).render("the quick brown fox jumps over")
