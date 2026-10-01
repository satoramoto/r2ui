# In static mode, blink messages neither toggle the cursor nor schedule another blink.
require "bubbletea"
require "bubbles"

cursor = Bubbles::Cursor.new
cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
cursor.focus
cursor, c1 = cursor.update(Bubbles::Cursor::InitialBlinkMessage.new)
cursor, c2 = cursor.update(Bubbles::Cursor::BlinkMessage.new(id: cursor.id, tag: 1))
[cursor.blink?, c1.nil?, c2.nil?].inspect
