# Attribute predicates report what was set and what was not.
require "lipgloss"

s = Lipgloss::Style.new.bold(true).underline(true).italic(false)
[s.bold?, s.italic?, s.underline?, s.faint?, s.blink?, s.reverse?, s.strikethrough?].inspect
