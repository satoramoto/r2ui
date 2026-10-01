# An unrecognised enumerator symbol falls back to the default.
require "lipgloss"

Lipgloss::Tree.root("Project").child("a", "b").enumerator(:bogus).render
