# CompleteColor foreground uses the true_color value under a truecolor terminal.
require "lipgloss"

c = Lipgloss::CompleteColor.new(true_color: "#0000FF", ansi256: 21, ansi: :blue)
Lipgloss::Style.new.foreground(c).render("complete")
