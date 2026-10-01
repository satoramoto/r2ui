# A BlinkMessage with an old tag or another cursor's id is ignored.
require "bubbletea"
require "bubbles"

cursor = Bubbles::Cursor.new
cursor.char = "s"
cursor.focus
cursor, command_stale = cursor.update(Bubbles::Cursor::BlinkMessage.new(id: cursor.id, tag: 99))
stale = [cursor.blink?, command_stale.nil?]
cursor, command_other = cursor.update(Bubbles::Cursor::BlinkMessage.new(id: cursor.id + 1000, tag: 1))
other = [cursor.blink?, command_other.nil?]
[stale, other].inspect
