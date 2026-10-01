# place measures styled content by visible width.
require "lipgloss"

Lipgloss.place(10, 3, :center, :center, Lipgloss::Style.new.bold(true).foreground("#04B575").render("hi"))
