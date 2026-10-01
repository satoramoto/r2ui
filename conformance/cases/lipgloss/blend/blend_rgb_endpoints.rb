# blend_rgb at t=0 and t=1 returns each endpoint.
require "lipgloss"

[0.0, 1.0].map { |t| Lipgloss::ColorBlend.blend_rgb("#336699", "#cc9933", t) }.inspect
