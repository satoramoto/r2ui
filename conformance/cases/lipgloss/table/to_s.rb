# to_s equals render.
require "lipgloss"

t = Lipgloss::Table.new.headers(["A"]).rows([["x"]])
[t.to_s == t.render, t.to_s].inspect
