# Rounded enumerator uses a rounded last-child corner.
require "lipgloss"

Lipgloss::Tree.root("Project").child("a", "b", "c").enumerator(:rounded).render
