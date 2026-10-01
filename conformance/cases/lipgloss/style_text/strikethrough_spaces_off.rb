# strikethrough_spaces(false) leaves the gaps between struck words unstyled.
require "lipgloss"

Lipgloss::Style.new.strikethrough(true).strikethrough_spaces(false).render("a b c")
