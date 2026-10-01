# Blink attribute alone wraps text in SGR 5.
require "lipgloss"

Lipgloss::Style.new.blink(true).render("Hello")
