# AdaptiveColor and CompleteAdaptiveColor to_h structures.
require "lipgloss"

a = Lipgloss::AdaptiveColor.new(light: "#111", dark: "#eee")
cc = Lipgloss::CompleteColor.new(true_color: "#123456", ansi256: 25, ansi: 4)
ca = Lipgloss::CompleteAdaptiveColor.new(light: cc, dark: cc)
[a.to_h, ca.to_h].inspect
