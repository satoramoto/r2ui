# A tick whose block returns nil delivers no message; a later tick still does.
require "bubbletea"

class Fired < Bubbletea::Message; end

class App
  include Bubbletea::Model

  def initialize
    @updates = 0
  end

  def init
    [self, Bubbletea.batch(Bubbletea.tick(0.05) { nil }, Bubbletea.tick(0.15) { Fired.new })]
  end

  def update(message)
    case message
    when Fired then @updates += 1
    when Bubbletea::KeyMessage then return [self, Bubbletea.quit] if message.to_s == "q"
    end
    [self, nil]
  end

  def view
    "fired: #{@updates}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - wait_for: "fired: 1"
    snapshot: one
  - keys: [q]
    exit: true
