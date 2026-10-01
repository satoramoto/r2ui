# AdaptiveColor whose light/dark are ANSI numbers rather than hex.
require "lipgloss"

c = Lipgloss::AdaptiveColor.new(light: "0", dark: "14")
Lipgloss::Style.new.foreground(c).render("adaptive")
