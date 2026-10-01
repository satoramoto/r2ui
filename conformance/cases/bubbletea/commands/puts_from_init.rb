# puts returned from init prints before the first view.
require "bubbletea"

class App
  include Bubbletea::Model

  def init
    [self, Bubbletea.puts("hello from init")]
  end

  def update(message)
    return [self, Bubbletea.quit] if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "q"

    [self, nil]
  end

  def view
    "live view"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x6
steps:
  - snapshot: start
  - keys: [q]
    exit: true
