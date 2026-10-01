# blends with an unparseable colour returns an empty array.
require "lipgloss"

Lipgloss::ColorBlend.blends("nope", "#ffffff", 4).inspect
