# tab_width(2) renders a tab as two spaces.
require "lipgloss"

Lipgloss::Style.new.tab_width(2).render("a\tb")
