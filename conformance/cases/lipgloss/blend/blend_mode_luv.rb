# blend with mode: :luv equals the default blend.
require "lipgloss"

Lipgloss::ColorBlend.blend("#00ff88", "#8800ff", 0.3, mode: Lipgloss::ColorBlend::LUV)
