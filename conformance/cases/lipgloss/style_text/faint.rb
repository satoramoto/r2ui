# Faint attribute alone wraps text in SGR 2.
require "lipgloss"

Lipgloss::Style.new.faint(true).render("Hello")
