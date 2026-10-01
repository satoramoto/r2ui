# blends with one step returns just the first colour.
require "lipgloss"

Lipgloss::ColorBlend.blends("#123456", "#abcdef", 1).inspect
