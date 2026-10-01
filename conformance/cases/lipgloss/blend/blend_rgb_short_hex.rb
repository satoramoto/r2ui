# blend_rgb accepts three-digit hex input and returns six-digit hex.
require "lipgloss"

Lipgloss::ColorBlend.blend_rgb("#f00", "#00f", 0.5)
