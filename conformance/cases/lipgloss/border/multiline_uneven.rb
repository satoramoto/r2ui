# Multi-line content of uneven widths is padded to the widest line.
require "lipgloss"

Lipgloss::Style.new.border(:normal).render("a\nlonger line\nmid")
