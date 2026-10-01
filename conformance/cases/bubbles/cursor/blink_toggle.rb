# A matching BlinkMessage toggles the cursor between shown and hidden.
require "bubbletea"
require "bubbles"

cursor = Bubbles::Cursor.new
cursor.char = "b"
cursor.focus
states = [cursor.blink?, cursor.view]
cursor, command = cursor.update(Bubbles::Cursor::BlinkMessage.new(id: cursor.id, tag: 1))
states << cursor.blink? << cursor.view << !command.nil?
cursor, = cursor.update(Bubbles::Cursor::BlinkMessage.new(id: cursor.id, tag: 2))
states << cursor.blink? << cursor.view
states.inspect
