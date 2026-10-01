# Italic attribute alone wraps text in SGR 3.
require "lipgloss"

Lipgloss::Style.new.italic(true).render("Hello")
