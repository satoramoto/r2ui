# inherit does not copy the parent's margins and padding.
require "lipgloss"

parent = Lipgloss::Style.new.padding(1, 2).margin(1, 2).bold(true)
Lipgloss::Style.new.inherit(parent).render("kid")
