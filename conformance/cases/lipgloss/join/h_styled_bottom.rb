# join_horizontal of styled blocks (background fill) aligned to bottom.
require "lipgloss"

a = Lipgloss::Style.new.background("#FF0000").padding(0, 1).render("a\nb\nc")
b = Lipgloss::Style.new.foreground("#00FF00").bold(true).render("xy")
Lipgloss.join_horizontal(:bottom, a, b)
