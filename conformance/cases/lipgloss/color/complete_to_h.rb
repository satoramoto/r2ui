# CompleteColor resolves symbols and integers to strings in to_h.
require "lipgloss"

Lipgloss::CompleteColor.new(true_color: "#0000FF", ansi256: 21, ansi: :bright_blue).to_h.inspect
