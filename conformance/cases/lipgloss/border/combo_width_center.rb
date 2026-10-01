# Width with centred alignment inside a border.
require "lipgloss"

Lipgloss::Style.new.border(:normal).width(12).align(:center).render("Box")
