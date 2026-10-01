# join_vertical of styled blocks aligned right; padding is plain spaces.
require "lipgloss"

a = Lipgloss::Style.new.background("#3C3C3C").render("wide block")
b = Lipgloss::Style.new.foreground("#04B575").bold(true).render("hi")
Lipgloss.join_vertical(:right, a, b)
