# to_s returns the same string as render.
require "lipgloss"

t = Lipgloss::Tree.root("R").child("a")
(t.to_s == t.render).to_s + t.to_s.inspect
