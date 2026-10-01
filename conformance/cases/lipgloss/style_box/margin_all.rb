# One margin argument adds blank space on all four sides.
require "lipgloss"

Lipgloss::Style.new.margin(1).render("ab")
