# KeyMessage.new with runes and alt: name is the packed runes, prefixed "alt+" when alt; char packs all runes.
require "bubbletea"

K = Bubbletea::KeyMessage
msgs = [
  K.new(key_type: K::KEY_RUNES, runes: [104]),
  K.new(key_type: K::KEY_RUNES, runes: [104, 105]),
  K.new(key_type: K::KEY_RUNES, runes: [955], alt: true),
  K.new(key_type: K::KEY_UP, alt: true),
  K.new(key_type: K::KEY_ENTER, alt: true),
  K.new(key_type: K::KEY_RUNES),
  K.new(key_type: K::KEY_RUNES, runes: "x"),
  K.new(key_type: K::KEY_SPACE, runes: [32])
]
msgs.map { |m| [m.to_s, m.key_type, m.runes, m.alt, m.char].inspect }.join("\n")
