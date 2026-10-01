# Foreground and background applied per line of multi-line text.
require "lipgloss"

Lipgloss::Style.new.foreground("#ffcc00").background("#222222").render("one\ntwo")
