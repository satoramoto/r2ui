# inherit does not override a colour the child already set.
require "lipgloss"

parent = Lipgloss::Style.new.foreground("#FF0000").bold(true)
Lipgloss::Style.new.foreground("#00FF00").inherit(parent).render("kid")
