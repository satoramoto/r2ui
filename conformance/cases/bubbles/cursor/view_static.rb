# In static mode a focused cursor is always shown, and blurring hides it again.
require "bubbletea"
require "bubbles"

cursor = Bubbles::Cursor.new
cursor.char = "x"
cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
cursor.focus
shown = cursor.view
cursor.blur
[shown, cursor.view].inspect
