# text_style styles the character while the cursor is in its hidden half (blurred).
require "bubbletea"
require "lipgloss"
require "bubbles"

cursor = Bubbles::Cursor.new
cursor.char = "t"
cursor.text_style = Lipgloss::Style.new.foreground("#00FF00")
cursor.view
