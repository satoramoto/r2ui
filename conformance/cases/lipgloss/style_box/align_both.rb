# align with two arguments sets horizontal then vertical position.
require "lipgloss"

Lipgloss::Style.new.width(7).height(3).align(:right, :bottom).render("ab")
