# send_message without a delay delivers the message to update right away.
require "bubbletea"

class Hello < Bubbletea::Message; end

class App
  include Bubbletea::Model

  def initialize
    @got = false
  end

  def init
    [self, Bubbletea.send_message(Hello.new)]
  end

  def update(message)
    case message
    when Hello then @got = true
    when Bubbletea::KeyMessage then return [self, Bubbletea.quit] if message.to_s == "q"
    end
    [self, nil]
  end

  def view
    "got hello: #{@got}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - wait_for: "got hello: true"
    snapshot: delivered
  - keys: [q]
    exit: true
