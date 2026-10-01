# blend with mode: :rgb matches plain RGB interpolation.
require "lipgloss"

Lipgloss::ColorBlend.blend("#ff0000", "#0000ff", 0.5, mode: Lipgloss::ColorBlend::RGB)
