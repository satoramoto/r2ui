# send_message with a delay arrives later: the first snapshot is still waiting, then it lands.
require "bubbletea"

class Late < Bubbletea::Message; end

class App
  include Bubbletea::Model

  def initialize
    @state = "waiting"
  end

  def init
    [self, Bubbletea.send_message(Late.new, delay: 0.8)]
  end

  def update(message)
    case message
    when Late then @state = "arrived"
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
  - wait_for: "state: arrived"
    snapshot: after
  - keys: [q]
    exit: true
