# A single word longer than the width is broken across lines.
require "lipgloss"

Lipgloss::Style.new.width(5).render("abcdefghijklmnop")
