# 256-colour grayscale ramp entries (232-255) as foreground.
require "lipgloss"

%w[232 240 248 255].map { |n| Lipgloss::Style.new.foreground(n).render("x") }.join("|")
