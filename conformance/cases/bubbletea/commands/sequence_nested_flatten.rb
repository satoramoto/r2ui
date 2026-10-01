# sequence accepts nested arrays and nils; the flattened commands run in order.
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
    list = [Bubbletea.send_message(Note.new("a")), nil, Bubbletea.send_message(Note.new("b"), delay: 0.1)]
    [self, Bubbletea.sequence(list, Bubbletea.send_message(Note.new("c")))]
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
  - wait_for: "order: a,b,c"
    snapshot: ordered
  - keys: [q]
    exit: true
