# Border around an empty string.
require "lipgloss"

Lipgloss::Style.new.border(:normal).render("")
