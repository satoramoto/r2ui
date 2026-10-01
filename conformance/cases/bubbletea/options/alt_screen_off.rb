# alt_screen: false (explicit) keeps the program on the main screen; the view stays after exit.
require "bubbletea"

class App
  include Bubbletea::Model

  def update(message)
    return [self, Bubbletea.quit] if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "q"

    [self, nil]
  end

  def view
    "inline view\nsecond line"
  end
end

Bubbletea.run(App.new, alt_screen: false)

__END__
size: 30x5
steps:
  - snapshot: running
  - keys: [q]
    exit: true
    snapshot: after_quit
