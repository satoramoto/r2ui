# Built-in :ascii border around one word.
require "lipgloss"

Lipgloss::Style.new.border(:ascii).render("Box")
