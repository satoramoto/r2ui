# A WindowSizeMessage with the terminal's width and height is delivered at startup (40x8 terminal).
require "bubbletea"

class App
  include Bubbletea::Model

  def initialize
    @size = "none yet"
  end

  def update(message)
    case message
    when Bubbletea::WindowSizeMessage then @size = "#{message.width}x#{message.height}"
    when Bubbletea::KeyMessage then return [self, Bubbletea.quit] if message.to_s == "q"
    end
    [self, nil]
  end

  def view
    "size: #{@size}"
  end
end

Bubbletea.run(App.new)

__END__
size: 40x8
steps:
  - snapshot: start
  - keys: [q]
    exit: true
