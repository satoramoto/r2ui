# FocusMessage, BlurMessage and the other event classes all descend from Bubbletea::Message.
require "bubbletea"

classes = %i[KeyMessage MouseMessage WindowSizeMessage FocusMessage BlurMessage QuitMessage ResumeMessage]
classes.map do |name|
  k = Bubbletea.const_get(name)
  "#{name} < Message: #{k < Bubbletea::Message}"
end.join("\n") + "\n" + Bubbletea::WindowSizeMessage.new(width: 80, height: 24).then { |m| [m.width, m.height].inspect }
