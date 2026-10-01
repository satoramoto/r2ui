# Enumerator style and item style together on an arabic list.
require "lipgloss"

Lipgloss::List.new.items(["Red", "Green", "Blue"]).enumerator(:arabic).enumerator_style(Lipgloss::Style.new.foreground("#FF0000")).item_style(Lipgloss::Style.new.italic(true).foreground("#00FF00")).render
