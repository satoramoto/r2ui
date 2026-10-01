# A lambda command that returns nil produces no message; the program keeps running.
require "bubbletea"

class App
  include Bubbletea::Model

  def initialize
    @updates = 0
  end

  def init
    [self, -> { nil }]
  end

  def update(message)
    case message
    when Bubbletea::KeyMessage
      return [self, Bubbletea.quit] if message.to_s == "q"

      @updates += 1
    end
    [self, nil]
  end

  def view
    "keys: #{@updates}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - snapshot: start
  - keys: [x]
    snapshot: one_key
  - keys: [q]
    exit: true
