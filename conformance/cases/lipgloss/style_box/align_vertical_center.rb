# align_vertical(:center) centres text within the height.
require "lipgloss"

Lipgloss::Style.new.height(5).align_vertical(:center).render("ab")
