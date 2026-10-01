# Lambdas inside a batch each run and deliver their messages.
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
    [self, Bubbletea.batch(-> { Note.new("one") }, -> { Note.new("two") })]
  end

  def update(message)
    case message
    when Note then @seen << message.text
    when Bubbletea::KeyMessage then return [self, Bubbletea.quit] if message.to_s == "q"
    end
    [self, nil]
  end

  def view
    "seen: #{@seen.sort.join(',')}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - wait_for: "seen: one,two"
    snapshot: both
  - keys: [q]
    exit: true
