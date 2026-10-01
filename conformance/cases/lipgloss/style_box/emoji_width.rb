# Emoji count as two cells when padding to a width.
require "lipgloss"

Lipgloss::Style.new.width(6).render("a😀b")
