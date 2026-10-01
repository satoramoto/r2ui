# BlinkMessage carries id and tag; the message classes are Bubbletea messages.
require "bubbletea"
require "bubbles"

m = Bubbles::Cursor::BlinkMessage.new(id: 7, tag: 3)
[m.id, m.tag, m.is_a?(Bubbletea::Message),
 Bubbles::Cursor::InitialBlinkMessage.new.is_a?(Bubbletea::Message),
 Bubbles::Cursor::BlinkCanceledMessage.new.is_a?(Bubbletea::Message)].inspect
