# A tick inside a sequence is scheduled when reached; messages still arrive in command order.
require "bubbletea"

class Note < Bubbletea::Message
  attr_reader :text

  def initialize(text)
    super()
    @text = text
  end
end

class App
  include Bubbletea::Model

  def initialize
    @seen = []
  end

  def init
    [self, Bubbletea.sequence(
      Bubbletea.send_message(Note.new("first")),
      Bubbletea.tick(0.1) { Note.new("tick") }
    )]
  end

  def update(message)
    case message
    when Note then @seen << message.text
    when Bubbletea::KeyMessage then return [self, Bubbletea.quit] if message.to_s == "q"
    end
    [self, nil]
  end

  def view
    "seen: #{@seen.join(',')}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - wait_for: "seen: first,tick"
    snapshot: both
  - keys: [q]
    exit: true
