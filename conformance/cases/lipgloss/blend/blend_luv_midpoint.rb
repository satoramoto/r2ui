# blend_luv at t=0.5 between green and magenta.
require "lipgloss"

Lipgloss::ColorBlend.blend_luv("#00ff00", "#ff00ff", 0.5)
