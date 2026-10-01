# get_width and get_height return what was configured (nil/0 when unset).
require "lipgloss"

[Lipgloss::Style.new.get_width, Lipgloss::Style.new.width(12).get_width, Lipgloss::Style.new.height(3).get_height].inspect
