# Startup order: init's own immediate message is handled first, then the WindowSizeMessage.
require "bubbletea"

class Hello < Bubbletea::Message; end

class App
  include Bubbletea::Model

  def initialize
    @order = []
  end

  def init
    [self, Bubbletea.send_message(Hello.new)]
  end

  def update(message)
    case message
    when Hello then @order << "hello"
    when Bubbletea::WindowSizeMessage then @order << "size"
    when Bubbletea::KeyMessage then return [self, Bubbletea.quit] if message.to_s == "q"
    end
    [self, nil]
  end

  def view
    "order: #{@order.join(',')}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - snapshot: start
  - keys: [q]
    exit: true
