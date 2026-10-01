# Alphabet enumerator past Z rolls over to AA.
require "lipgloss"

Lipgloss::List.new.items((1..28).map { |i| "i#{i}" }).enumerator(:alphabet).render
