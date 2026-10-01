# mouse_all_motion: true turns on all-motion mouse reporting while running and off again on exit.
require "bubbletea"

class App
  include Bubbletea::Model

  def update(message)
    return [self, Bubbletea.quit] if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "q"

    [self, nil]
  end

  def view
    "mouse all motion"
  end
end

Bubbletea.run(App.new, mouse_all_motion: true)

__END__
size: 30x5
steps:
  - snapshot: running
  - keys: [q]
    exit: true
    snapshot: after_quit
