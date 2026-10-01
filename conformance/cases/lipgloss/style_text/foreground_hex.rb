# Foreground from a hex string gives a true-colour SGR 38;2.
require "lipgloss"

Lipgloss::Style.new.foreground("#00FF7F").render("green")
