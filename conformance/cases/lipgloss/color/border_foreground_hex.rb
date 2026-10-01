# border_foreground with a hex colour on all sides.
require "lipgloss"

Lipgloss::Style.new.border(:rounded).border_foreground("#FF00AA").render("Box")
