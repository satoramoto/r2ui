# Several attributes plus both colours combine into one SGR sequence.
require "lipgloss"

Lipgloss::Style.new.bold(true).italic(true).underline(true).foreground("#FFFFFF").background("#880000").render("Alert")
