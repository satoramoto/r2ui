# sequence delivers its messages strictly in order, even when an earlier one has a longer delay.
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
      Bubbletea.send_message(Note.new("1"), delay: 0.15),
      Bubbletea.send_message(Note.new("2")),
      Bubbletea.send_message(Note.new("3"), delay: 0.05)
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
    "order: #{@seen.join(',')}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - wait_for: "order: 1,2,3"
    snapshot: ordered
  - keys: [q]
    exit: true
