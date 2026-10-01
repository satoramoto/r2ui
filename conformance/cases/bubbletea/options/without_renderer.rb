# without_renderer: true runs the loop but draws no view; the model still receives keys and can quit.
require "bubbletea"

class App
  include Bubbletea::Model

  def update(message)
    return [self, Bubbletea.quit] if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "q"

    [self, nil]
  end

  def view
    "should not appear"
  end
end

Bubbletea.run(App.new, without_renderer: true)

__END__
size: 30x4
steps:
  - snapshot: running
  - keys: [q]
    exit: true
    snapshot: after_quit
