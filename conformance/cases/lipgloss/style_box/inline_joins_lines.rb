# inline(true) removes newlines from the text.
require "lipgloss"

Lipgloss::Style.new.inline(true).render("a\nb\nc")
