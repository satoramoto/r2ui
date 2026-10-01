# Roman numeral enumerator.
require "lipgloss"

Lipgloss::List.new.items((1..9).map { |i| "item #{i}" }).enumerator(:roman).render
