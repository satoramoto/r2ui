# Lists nested two levels deep.
require "lipgloss"

inner = Lipgloss::List.new.items(["deep"])
mid = Lipgloss::List.new.items(["mid"]).item(inner)
Lipgloss::List.new.items(["top"]).item(mid).render
