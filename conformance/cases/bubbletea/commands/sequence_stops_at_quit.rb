# sequence stops at a quit: commands after it never run, the earlier message is delivered.
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
    [self, Bubbletea.sequence(Bubbletea.send_message(Note.new("before")), Bubbletea.quit, Bubbletea.send_message(Note.new("after")))]
  end

  def update(message)
    @seen << message.text if message.is_a?(Note)
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
  - exit: true
    snapshot: exited
