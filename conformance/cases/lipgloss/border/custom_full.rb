# border_custom with every part set.
require "lipgloss"

Lipgloss::Style.new.border_custom(top: "~", bottom: "=", left: "(", right: ")", top_left: "1", top_right: "2", bottom_left: "3", bottom_right: "4").render("Box")
