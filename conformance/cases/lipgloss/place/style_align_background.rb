# Style align with a background colour: padding takes the background.
require "lipgloss"

Lipgloss::Style.new.width(8).align_horizontal(:center).background("#3C3C3C").render("ab")
