# InitialBlinkMessage on a focused blink-mode cursor returns a command to schedule the next blink.
require "bubbletea"
require "bubbles"

cursor = Bubbles::Cursor.new
cursor.focus
cursor, command = cursor.update(Bubbles::Cursor::InitialBlinkMessage.new)
[cursor.blink?, command.nil?].inspect
