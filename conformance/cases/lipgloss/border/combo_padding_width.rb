# Border with padding and fixed width together.
require "lipgloss"

Lipgloss::Style.new.border(:double).padding(0, 2).width(14).render("Box")
