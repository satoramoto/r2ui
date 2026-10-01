# A long tick has not fired while the screen is idle at start (0.8s tick, snapshot after ~0.3s), then fires.
require "bubbletea"

class Fired < Bubbletea::Message; end

class App
  include Bubbletea::Model

  def initialize
    @state = "waiting"
  end

  def init
    [self, Bubbletea.tick(0.8) { Fired.new }]
  end

  def update(message)
    case message
    when Fired then @state = "fired"
    when Bubbletea::KeyMessage then return [self, Bubbletea.quit] if message.to_s == "q"
    end
    [self, nil]
  end

  def view
    "state: #{@state}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - snapshot: before
  - wait_for: "state: fired"
    snapshot: after
  - keys: [q]
    exit: true
