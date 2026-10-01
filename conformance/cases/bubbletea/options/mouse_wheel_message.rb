# With mouse_cell_motion, wheel events arrive as MouseMessages with the wheel buttons.
require "bubbletea"

class App
  include Bubbletea::Model

  def initialize
    @log = []
  end

  def update(message)
    case message
    when Bubbletea::KeyMessage then return [self, Bubbletea.quit] if message.to_s == "q"
    when Bubbletea::MouseMessage
      @log << "#{message.wheel? ? 'wheel' : 'other'}:b#{message.button}"
    end
    [self, nil]
  end

  def view
    "events: #{@log.join(' ')}"
  end
end

Bubbletea.run(App.new, mouse_cell_motion: true)

__END__
size: 50x4
steps:
  - snapshot: start
  - input: "\e[<64;10;5M"
    snapshot: up
  - input: "\e[<65;10;5M"
    snapshot: down
  - keys: [q]
    exit: true
