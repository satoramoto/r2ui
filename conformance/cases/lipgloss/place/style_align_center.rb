# Style#align_horizontal(:center) with a width centers each line.
require "lipgloss"

Lipgloss::Style.new.width(9).align_horizontal(:center).render("ab\nc")
