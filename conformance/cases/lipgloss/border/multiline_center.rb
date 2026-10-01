# Multi-line content centred inside a border.
require "lipgloss"

Lipgloss::Style.new.border(:normal).align(:center).render("a\nlonger line\nmid")
