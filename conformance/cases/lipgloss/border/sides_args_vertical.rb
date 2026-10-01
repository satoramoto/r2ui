# border(type, true, false) enables top and bottom only (CSS-style side args).
require "lipgloss"

Lipgloss::Style.new.border(:normal, true, false).render("Box")
