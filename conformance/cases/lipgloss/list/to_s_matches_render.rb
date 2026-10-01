# to_s returns the same string as render.
require "lipgloss"

l = Lipgloss::List.new.items(["a", "b"]).enumerator(:dash)
[l.to_s, l.render].inspect + (l.to_s == l.render).to_s
