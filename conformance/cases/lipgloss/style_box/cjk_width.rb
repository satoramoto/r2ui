# East Asian wide characters count as two cells when padding to a width.
require "lipgloss"

Lipgloss::Style.new.width(8).render("日本語")
