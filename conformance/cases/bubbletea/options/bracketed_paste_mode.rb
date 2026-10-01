# bracketed_paste: true enables bracketed paste while running and disables it on exit.
require "bubbletea"

class App
  include Bubbletea::Model

  def update(message)
    return [self, Bubbletea.quit] if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "q"

    [self, nil]
  end

  def view
    "bracketed paste"
  end
end

Bubbletea.run(App.new, bracketed_paste: true)

__END__
size: 30x5
steps:
  - snapshot: running
  - keys: [q]
    exit: true
    snapshot: after_quit
