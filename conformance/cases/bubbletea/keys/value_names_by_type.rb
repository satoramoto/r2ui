# KeyMessage.new(key_type:) derives its name from the type; unknown types are "unknown", runes without a rune is "runes".
require "bubbletea"

types = (0..31).to_a + [127] + (-25..-1).to_a + [-100, -200, 99, 128]
types.map do |t|
  m = Bubbletea::KeyMessage.new(key_type: t)
  "#{t} #{m.to_s.inspect} #{m.name.inspect} char=#{m.char.inspect}"
end.join("\n")
