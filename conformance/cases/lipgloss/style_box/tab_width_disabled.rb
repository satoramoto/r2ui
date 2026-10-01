# tab_width(-1) leaves the tab character untouched.
require "lipgloss"

Lipgloss::Style.new.tab_width(-1).render("a\tb")
