# inherit copies the parent's properties the child has not set.
require "lipgloss"

parent = Lipgloss::Style.new.bold(true).foreground("#FF0000").background("#0000FF")
Lipgloss::Style.new.italic(true).inherit(parent).render("kid")
