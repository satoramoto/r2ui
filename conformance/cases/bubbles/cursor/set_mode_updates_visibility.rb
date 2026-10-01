# Changing mode on a focused cursor resets its visibility: hide hides it, static shows it.
require "bubbletea"
require "bubbles"

cursor = Bubbles::Cursor.new
cursor.char = "m"
cursor.focus
views = [cursor.view]
cursor.set_mode(Bubbles::Cursor::MODE_HIDE)
views << cursor.view
cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
views << cursor.view
views.inspect
