# blend_luv between black and white at several t values.
require "lipgloss"

[0.0, 0.25, 0.5, 0.75, 1.0].map { |t| Lipgloss::ColorBlend.blend_luv("#000000", "#ffffff", t) }.inspect
