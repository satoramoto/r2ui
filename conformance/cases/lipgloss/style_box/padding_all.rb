# One padding argument pads all four sides equally.
require "lipgloss"

Lipgloss::Style.new.padding(1).render("ab")
