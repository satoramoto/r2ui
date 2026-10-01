# blend_rgb at t=0.25 with unequal channels (rounding).
require "lipgloss"

Lipgloss::ColorBlend.blend_rgb("#102030", "#f0e0d0", 0.25)
