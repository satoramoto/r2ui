# max_height drops lines beyond the limit.
require "lipgloss"

Lipgloss::Style.new.max_height(2).render("a\nb\nc\nd")
