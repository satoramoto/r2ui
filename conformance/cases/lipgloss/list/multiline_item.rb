# A multi-line item indents its continuation lines under the text.
require "lipgloss"

Lipgloss::List.new.items(["first
second", "third"]).enumerator(:arabic).render
