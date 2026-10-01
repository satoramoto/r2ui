# blends with two steps returns exactly the endpoints.
require "lipgloss"

Lipgloss::ColorBlend.blends("#123456", "#abcdef", 2, mode: Lipgloss::ColorBlend::RGB).inspect
