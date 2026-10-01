# An unrecognised enumerator symbol falls back to the bullet.
require "lipgloss"

Lipgloss::List.new.items(["a", "b"]).enumerator(:custom).render
