# Predicate truth table (ctrl? runes? space? enter? backspace? tab? esc? up? down? left? right?) per key type.
require "bubbletea"

K = Bubbletea::KeyMessage
preds = %i[ctrl? runes? space? enter? backspace? tab? esc? up? down? left? right?]
types = { null: 0, ctrl_a: 1, tab: 9, enter: 13, ctrl_z: 26, esc: 27, backspace: 127, runes: -1, up: -2,
          down: -3, right: -4, left: -5, home: -6, f1: -12, shift_tab: -24, space: -25 }
types.map do |label, t|
  m = K.new(key_type: t)
  "#{label}: #{preds.select { |p| m.public_send(p) }.map { |p| p.to_s.chomp('?') }.join(',')}"
end.join("\n")
