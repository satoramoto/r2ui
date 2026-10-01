# set_mode accepts blink/static/hide, ignores unknown modes, and only blink mode returns a command.
require "bubbletea"
require "bubbles"

cursor = Bubbles::Cursor.new
modes = [cursor.mode]
modes << cursor.set_mode(Bubbles::Cursor::MODE_STATIC).nil? << cursor.mode
modes << cursor.set_mode(Bubbles::Cursor::MODE_HIDE).nil? << cursor.mode
modes << cursor.set_mode(:bogus).nil? << cursor.mode
modes << cursor.set_mode(Bubbles::Cursor::MODE_BLINK).nil? << cursor.mode
modes.inspect
