# render with an argument on a style that has set_string: shows how both strings combine.
require "lipgloss"

Lipgloss::Style.new.underline(true).set_string("Stored").render("Arg")
