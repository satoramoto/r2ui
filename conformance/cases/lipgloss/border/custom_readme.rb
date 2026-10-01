# The README custom border example.
require "lipgloss"

Lipgloss::Style.new.border_custom(top: "~", bottom: "~", left: "|", right: "|", top_left: "+", top_right: "+", bottom_left: "+", bottom_right: "+").render("Custom border!")
