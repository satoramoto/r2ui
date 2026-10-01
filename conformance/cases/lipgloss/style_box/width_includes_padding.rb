# width includes padding, so wrapping happens at width minus horizontal padding.
require "lipgloss"

Lipgloss::Style.new.width(10).padding(0, 2).render("the quick brown fox")
