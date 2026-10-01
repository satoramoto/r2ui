# A lambda used as a command runs off the main loop; its returned Message is delivered to update.
require "bubbletea"

class Loaded < Bubbletea::Message
  attr_reader :data

  def initialize(data)
    super()
    @data = data
  end
end

class App
  include Bubbletea::Model

  def initialize
    @data = "loading"
  end

  def init
    [self, -> { Loaded.new("ready") }]
  end

  def update(message)
    case message
    when Loaded then @data = message.data
    when Bubbletea::KeyMessage then return [self, Bubbletea.quit] if message.to_s == "q"
    end
    [self, nil]
  end

  def view
    "data: #{@data}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - wait_for: "data: ready"
    snapshot: loaded
  - keys: [q]
    exit: true
