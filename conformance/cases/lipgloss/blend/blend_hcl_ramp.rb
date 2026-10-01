# blend_hcl between red and green at several t values.
require "lipgloss"

[0.0, 0.2, 0.4, 0.6, 0.8, 1.0].map { |t| Lipgloss::ColorBlend.blend_hcl("#ff0000", "#00ff00", t) }.inspect
