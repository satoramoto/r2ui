# Bold coloured content inside a coloured border.
require "lipgloss"

Lipgloss::Style.new.border(:rounded).border_foreground("#7D56F4").bold(true).foreground("#FAFAFA").render("Hi")
