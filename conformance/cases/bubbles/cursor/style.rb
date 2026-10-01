# A custom cursor style is applied (with reverse) when the cursor is shown.
require "bubbletea"
require "lipgloss"
require "bubbles"

cursor = Bubbles::Cursor.new
cursor.char = "c"
cursor.style = Lipgloss::Style.new.foreground("#FF0000")
cursor.focus
cursor.view
