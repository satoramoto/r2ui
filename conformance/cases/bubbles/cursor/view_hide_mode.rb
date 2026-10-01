# In hide mode the cursor is never drawn highlighted, focused or not.
require "bubbletea"
require "bubbles"

cursor = Bubbles::Cursor.new
cursor.char = "h"
cursor.set_mode(Bubbles::Cursor::MODE_HIDE)
before = cursor.view
cursor.focus
[before, cursor.view].inspect
