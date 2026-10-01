# Explicit :default enumerator.
require "lipgloss"

Lipgloss::Tree.root("Project").child("a", "b").enumerator(:default).render
