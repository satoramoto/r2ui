# A foreground colour on the enumerator marker only.
require "lipgloss"

Lipgloss::List.new.items(["Red", "Green"]).enumerator(:bullet).enumerator_style(Lipgloss::Style.new.foreground("#FF0000")).render
