# blends with mode: :rgb and 3 steps includes both endpoints.
require "lipgloss"

Lipgloss::ColorBlend.blends("#000000", "#ffffff", 3, mode: Lipgloss::ColorBlend::RGB).inspect
