# inline(true) ignores padding and margin but keeps text styling.
require "lipgloss"

Lipgloss::Style.new.inline(true).padding(1, 2).margin(1, 2).bold(true).render("ab")
