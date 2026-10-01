# CompleteAdaptiveColor foreground under a dark truecolor terminal.
require "lipgloss"

light = Lipgloss::CompleteColor.new(true_color: "#000011", ansi256: :black, ansi: :black)
dark = Lipgloss::CompleteColor.new(true_color: "#ffffee", ansi256: :bright_white, ansi: :bright_white)
c = Lipgloss::CompleteAdaptiveColor.new(light: light, dark: dark)
Lipgloss::Style.new.foreground(c).render("ca")
