# height smaller than the content does not cut lines off.
require "lipgloss"

Lipgloss::Style.new.height(2).render("a\nb\nc\nd")
