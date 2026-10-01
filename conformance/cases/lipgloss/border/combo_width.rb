# Fixed width wider than content; border wraps the padded width.
require "lipgloss"

Lipgloss::Style.new.border(:normal).width(12).render("Box")
