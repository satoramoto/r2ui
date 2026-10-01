# AdaptiveColor foreground picks a side from the (dark) terminal background.
require "lipgloss"

c = Lipgloss::AdaptiveColor.new(light: "#112233", dark: "#ddeeff")
Lipgloss::Style.new.foreground(c).render("adaptive")
