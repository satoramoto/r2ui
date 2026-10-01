# blends with mode: :hcl and 4 steps.
require "lipgloss"

Lipgloss::ColorBlend.blends("#ff8800", "#0088ff", 4, mode: Lipgloss::ColorBlend::HCL).inspect
