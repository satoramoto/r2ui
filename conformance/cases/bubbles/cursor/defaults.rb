# Fresh cursor defaults: blink mode, 0.53s blink speed, empty char, unfocused, hidden half.
require "bubbletea"
require "bubbles"

cursor = Bubbles::Cursor.new
[cursor.mode, cursor.blink_speed, cursor.char, cursor.focused?, cursor.blink?,
 cursor.style, cursor.text_style, Bubbles::Cursor::DEFAULT_BLINK_SPEED].inspect
