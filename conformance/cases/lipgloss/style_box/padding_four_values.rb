# Four padding arguments are top, right, bottom, left.
require "lipgloss"

Lipgloss::Style.new.padding(1, 2, 0, 4).render("ab")
