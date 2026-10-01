# max_width truncates wide characters by cell width.
require "lipgloss"

Lipgloss::Style.new.max_width(5).render("日本語テキスト")
