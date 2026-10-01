# unset_foreground and unset_background drop the colours but keep bold.
require "lipgloss"

Lipgloss::Style.new.bold(true).foreground("#FF0000").background("#0000FF").unset_foreground.unset_background.render("x")
