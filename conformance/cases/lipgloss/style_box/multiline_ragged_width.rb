# Lines of unequal length are padded to the widest line when a background is set.
require "lipgloss"

Lipgloss::Style.new.background("#444444").render("a\nbbbb\ncc")
