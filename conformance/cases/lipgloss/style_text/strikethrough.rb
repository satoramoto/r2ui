# Strikethrough attribute on text containing a space.
require "lipgloss"

Lipgloss::Style.new.strikethrough(true).render("Hello World")
