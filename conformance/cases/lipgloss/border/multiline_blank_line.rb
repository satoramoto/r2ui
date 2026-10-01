# Content with an empty middle line.
require "lipgloss"

Lipgloss::Style.new.border(:normal).render("top\n\nbottom")
