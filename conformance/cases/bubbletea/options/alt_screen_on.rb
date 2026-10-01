# alt_screen: true draws on the alternate screen and restores the main screen on exit.
require "bubbletea"

class App
  include Bubbletea::Model

  def update(message)
    return [self, Bubbletea.quit] if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "q"

    [self, nil]
  end

  def view
    "in the alt screen"
  end
end

Bubbletea.run(App.new, alt_screen: true)

__END__
size: 30x5
steps:
  - snapshot: running
  - keys: [q]
    exit: true
    snapshot: after_quit
