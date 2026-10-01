# Reverse attribute alone wraps text in SGR 7.
require "lipgloss"

Lipgloss::Style.new.reverse(true).render("Hello")
