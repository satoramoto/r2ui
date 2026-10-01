# A tick fires once after its duration, delivering the block's return value as the message.
require "bubbletea"

class Fired < Bubbletea::Message
  attr_reader :value

  def initialize(value)
    super()
    @value = value
  end
end

class App
  include Bubbletea::Model

  def initialize
    @fired = []
  end

  def init
    [self, Bubbletea.tick(0.1) { Fired.new(42) }]
  end

  def update(message)
    case message
    when Fired then @fired << message.value
    when Bubbletea::KeyMessage then return [self, Bubbletea.quit] if message.to_s == "q"
    end
    [self, nil]
  end

  def view
    "fired: #{@fired.inspect}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - wait_for: "fired: [42]"
    snapshot: fired_once
  - keys: [q]
    exit: true
