# clear_rows drops rows but keeps headers.
require "lipgloss"

Lipgloss::Table.new.headers(["K", "V"]).rows([["a", "1"]]).clear_rows.render
