# underline_spaces(true) underlines the spaces between words as well.
require "lipgloss"

Lipgloss::Style.new.underline(true).underline_spaces(true).render("a b c")
