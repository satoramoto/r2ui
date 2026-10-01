# join_horizontal measures styled blocks by visible width, not escape bytes.
require "lipgloss"

a = Lipgloss::Style.new.foreground("#FF8700").render("one\nthree")
Lipgloss.join_horizontal(:top, a, "|", Lipgloss::Style.new.italic(true).render("z"))
