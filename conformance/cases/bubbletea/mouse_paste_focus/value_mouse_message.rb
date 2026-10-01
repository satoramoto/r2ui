# MouseMessage constants, constructor defaults, and predicates for built messages.
require "bubbletea"

M = Bubbletea::MouseMessage
consts = M.constants.sort_by { |c| [M.const_get(c), c] }.map { |c| "#{c}=#{M.const_get(c)}" }
msgs = [
  M.new(x: 1, y: 2, button: M::BUTTON_LEFT, action: M::ACTION_PRESS),
  M.new(x: 3, y: 4, button: M::BUTTON_MIDDLE, action: M::ACTION_RELEASE, shift: true),
  M.new(x: 5, y: 6, button: M::BUTTON_RIGHT, action: M::ACTION_MOTION, alt: true, ctrl: true),
  M.new(x: 0, y: 0, button: M::BUTTON_WHEEL_UP, action: M::ACTION_PRESS),
  M.new(x: 0, y: 0, button: M::BUTTON_WHEEL_DOWN, action: M::ACTION_PRESS),
  M.new(x: 0, y: 0, button: M::BUTTON_NONE, action: M::ACTION_MOTION)
]
rows = msgs.map do |m|
  flags = %i[press? release? motion? wheel? left? right? middle?].select { |f| m.public_send(f) }
  [m.x, m.y, m.button, m.action, m.shift, m.alt, m.ctrl, flags].inspect
end
(consts + rows).join("\n")
