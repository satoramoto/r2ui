# A focused cursor with no character set renders just the reverse-video markers (an empty highlight).
require "bubbletea"
require "bubbles"

cursor = Bubbles::Cursor.new
cursor.focus
cursor.view
