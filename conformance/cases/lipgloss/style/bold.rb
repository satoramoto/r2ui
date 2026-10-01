# Bold, true-colour foreground on a single word.
require "lipgloss"

Lipgloss::Style.new.bold(true).foreground("#FF8700").render("Hello")
