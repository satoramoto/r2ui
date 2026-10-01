# 256-colour palette entries as background.
require "lipgloss"

%w[17 100 208 244].map { |n| Lipgloss::Style.new.background(n).render("x") }.join("|")
