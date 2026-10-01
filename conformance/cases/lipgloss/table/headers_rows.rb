# Headers plus rows with the default border.
require "lipgloss"

Lipgloss::Table.new.headers(["Name", "Age"]).rows([["Alice", "30"], ["Bob", "4"]]).render
