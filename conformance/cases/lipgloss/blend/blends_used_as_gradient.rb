# A blends ramp used as per-character foreground colours.
require "lipgloss"

ramp = Lipgloss::ColorBlend.blends("#ff0000", "#0000ff", 5, mode: Lipgloss::ColorBlend::RGB)
"ABCDE".chars.each_with_index.map { |ch, i| Lipgloss::Style.new.foreground(ramp[i]).render(ch) }.join
