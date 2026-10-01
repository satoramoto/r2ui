# align_horizontal(:right) right-justifies lines within the width.
require "lipgloss"

Lipgloss::Style.new.width(8).align_horizontal(:right).render("a\nbbb")
