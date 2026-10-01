# Foreground from an ANSI index string (basic and 256-colour range).
require "lipgloss"

[
  Lipgloss::Style.new.foreground("1").render("red"),
  Lipgloss::Style.new.foreground("12").render("bright"),
  Lipgloss::Style.new.foreground("201").render("pink")
].join("|")
