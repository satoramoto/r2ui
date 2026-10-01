# An explicit name: wins over the derived name (and is not given an alt+ prefix).
require "bubbletea"

K = Bubbletea::KeyMessage
a = K.new(key_type: K::KEY_UP, name: "custom")
b = K.new(key_type: K::KEY_RUNES, runes: [120], alt: true, name: "named")
[a.to_s, a.name, b.to_s, b.name, b.alt].inspect
