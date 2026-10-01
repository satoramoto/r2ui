# strikethrough_spaces(true) strikes through the spaces between words.
require "lipgloss"

Lipgloss::Style.new.strikethrough(true).strikethrough_spaces(true).render("a b c")
