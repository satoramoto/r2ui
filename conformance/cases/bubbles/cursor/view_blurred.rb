# A new, unfocused cursor draws its character plain (no reverse video).
require "bubbletea"
require "bubbles"

cursor = Bubbles::Cursor.new
cursor.char = "a"
cursor.view
