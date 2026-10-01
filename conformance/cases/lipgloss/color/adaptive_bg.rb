# AdaptiveColor background picks a side from the terminal background.
require "lipgloss"

c = Lipgloss::AdaptiveColor.new(light: "#ffeecc", dark: "#220044")
Lipgloss::Style.new.background(c).render("adaptive")
