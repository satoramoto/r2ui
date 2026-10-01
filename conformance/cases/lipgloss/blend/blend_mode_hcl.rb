# blend with mode: :hcl interpolates in HCL space.
require "lipgloss"

Lipgloss::ColorBlend.blend("#ff0000", "#0000ff", 0.5, mode: Lipgloss::ColorBlend::HCL)
