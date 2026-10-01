# Each cursor gets a distinct, increasing id.
require "bubbletea"
require "bubbles"

a = Bubbles::Cursor.new
b = Bubbles::Cursor.new
[a.id != b.id, b.id > a.id].inspect
