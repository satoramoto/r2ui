# Focusing in the default blink mode starts with the cursor shown (reverse video).
require "bubbletea"
require "bubbles"

cursor = Bubbles::Cursor.new
cursor.char = "a"
cursor.focus
cursor.view
