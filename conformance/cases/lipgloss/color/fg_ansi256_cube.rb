# 256-colour palette entries from the colour cube as foreground.
require "lipgloss"

%w[16 21 46 82 196 201 231].map { |n| Lipgloss::Style.new.foreground(n).render("x") }.join("|")
