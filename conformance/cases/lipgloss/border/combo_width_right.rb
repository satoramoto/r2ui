# Width with right alignment inside a border.
require "lipgloss"

Lipgloss::Style.new.border(:rounded).width(12).align(:right).render("Box")
