# BlinkMessage and InitialBlinkMessage do nothing to a blurred cursor.
require "bubbletea"
require "bubbles"

cursor = Bubbles::Cursor.new
cursor.char = "z"
cursor, c1 = cursor.update(Bubbles::Cursor::InitialBlinkMessage.new)
cursor, c2 = cursor.update(Bubbles::Cursor::BlinkMessage.new(id: cursor.id, tag: 0))
[cursor.blink?, c1.nil?, c2.nil?].inspect
