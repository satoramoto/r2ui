# Underline attribute on text containing a space.
require "lipgloss"

Lipgloss::Style.new.underline(true).render("Hello World")
