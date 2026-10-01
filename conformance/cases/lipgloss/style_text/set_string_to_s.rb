# set_string stores text that to_s renders with the style.
require "lipgloss"

Lipgloss::Style.new.bold(true).foreground("#00BFFF").set_string("Stored").to_s
