# join_horizontal pads each line of a block to the block's widest line.
require "lipgloss"

Lipgloss.join_horizontal(:top, "a\nlonger\nbc", "|", "x\ny")
