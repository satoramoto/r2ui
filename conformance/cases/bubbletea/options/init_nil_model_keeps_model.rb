# init returning [nil, command] keeps the original model and still runs the command.
require "bubbletea"

class Hello < Bubbletea::Message; end

class App
  include Bubbletea::Model

  def initialize
    @greeted = false
  end

  def init
    [nil, Bubbletea.send_message(Hello.new)]
  end

  def update(message)
    case message
    when Hello then @greeted = true
    when Bubbletea::KeyMessage then return [self, Bubbletea.quit] if message.to_s == "q"
    end
    [self, nil]
  end

  def view
    "greeted: #{@greeted}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - wait_for: "greeted: true"
    snapshot: greeted
  - keys: [q]
    exit: true
