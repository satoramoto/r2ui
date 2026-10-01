# max_width truncates each line to the limit.
require "lipgloss"

Lipgloss::Style.new.max_width(5).render("abcdefghij\nxy")
