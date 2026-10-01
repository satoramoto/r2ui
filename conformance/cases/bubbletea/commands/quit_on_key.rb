# Bubbletea.quit returned from update ends the program and the final view stays on screen.
require "bubbletea"

class App
  include Bubbletea::Model

  def update(message)
    return [self, Bubbletea.quit] if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "q"

    [self, nil]
  end

  def view
    "press q"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - snapshot: start
  - keys: [q]
    exit: true
    snapshot: quit
