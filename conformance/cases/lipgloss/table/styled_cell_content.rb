# Cells holding pre-rendered ANSI text are measured without escapes.
require "lipgloss"

red = Lipgloss::Style.new.foreground("#FF0000").render("err")
Lipgloss::Table.new.headers(["Level", "Msg"]).rows([[red, "boom"], ["ok", "fine"]]).render
