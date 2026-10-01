# Bold attribute alone wraps text in SGR 1.
require "lipgloss"

Lipgloss::Style.new.bold(true).render("Hello")
