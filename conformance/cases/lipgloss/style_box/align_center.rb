# align_horizontal(:center) centres lines within the width (odd leftover space).
require "lipgloss"

Lipgloss::Style.new.width(8).align_horizontal(:center).render("a\nbbb")
