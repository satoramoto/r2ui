# Border foreground and background together.
require "lipgloss"

Lipgloss::Style.new.border(:rounded).border_foreground("#FFFFFF").border_background("#333333").render("Box")
