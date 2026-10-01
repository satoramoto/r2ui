# Underline with underline_spaces(false) leaves the gaps between words unstyled.
require "lipgloss"

Lipgloss::Style.new.underline(true).underline_spaces(false).render("a b c")
