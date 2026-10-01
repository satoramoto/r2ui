# Wide characters wrap by cell width, never splitting a character.
require "lipgloss"

Lipgloss::Style.new.width(5).render("日本語テキスト")
