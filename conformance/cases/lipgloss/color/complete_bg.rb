# CompleteColor background uses the true_color value under a truecolor terminal.
require "lipgloss"

c = Lipgloss::CompleteColor.new(true_color: "#ff7700", ansi256: "208", ansi: "3")
Lipgloss::Style.new.background(c).render("complete")
