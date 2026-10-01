# unset_bold removes bold but keeps italic.
require "lipgloss"

Lipgloss::Style.new.bold(true).italic(true).unset_bold.render("x")
