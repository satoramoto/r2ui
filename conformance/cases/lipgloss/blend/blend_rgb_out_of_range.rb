# blend_rgb with t outside 0..1 (clamped or extrapolated as upstream does).
require "lipgloss"

[1.5, -0.5].map { |t| Lipgloss::ColorBlend.blend_rgb("#000000", "#ffffff", t) }.inspect
