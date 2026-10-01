# Background from a hex string gives a true-colour SGR 48;2.
require "lipgloss"

Lipgloss::Style.new.background("#1E90FF").render("blue")
