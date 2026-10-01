# blend_rgb with an unparseable colour returns the first argument unchanged.
require "lipgloss"

[
  Lipgloss::ColorBlend.blend_rgb("#zzz", "#ffffff", 0.5),
  Lipgloss::ColorBlend.blend_rgb("#112233", "red", 0.5)
].inspect
