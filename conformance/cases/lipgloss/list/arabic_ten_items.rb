# Arabic numbers past 9 align their markers.
require "lipgloss"

Lipgloss::List.new.items((1..11).map { |i| "item #{i}" }).enumerator(:arabic).render
