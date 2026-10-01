# Two padding arguments are vertical then horizontal.
require "lipgloss"

Lipgloss::Style.new.padding(1, 3).render("ab")
