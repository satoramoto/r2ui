# join_horizontal of two bordered boxes of different heights, centered.
require "lipgloss"

s = Lipgloss::Style.new.border(:rounded)
Lipgloss.join_horizontal(:center, s.render("a\nb\nc"), s.render("xy"))
