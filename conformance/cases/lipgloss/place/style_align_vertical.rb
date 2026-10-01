# Style#align_vertical with a height: bottom and center.
require "lipgloss"

[Lipgloss::Style.new.height(5).align_vertical(:bottom).render("ab"), Lipgloss::Style.new.height(5).align_vertical(:center).render("ab")].join("\n--\n")
