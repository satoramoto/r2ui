# init returning a tick: the first view is drawn, then the tick fires and the view updates.
require "bubbletea"

class Fired < Bubbletea::Message; end

class App
  include Bubbletea::Model

  def initialize
    @state = "initial"
  end

  def init
    [self, Bubbletea.tick(0.8) { Fired.new }]
  end

  def update(message)
    case message
    when Fired then @state = "ticked"
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
  - snapshot: first_view
  - wait_for: "state: ticked"
    snapshot: after_tick
  - keys: [q]
    exit: true
