# With mouse_cell_motion, SGR mouse press/release events arrive as MouseMessages with 0-based x/y.
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
      @log << "x=#{message.x} y=#{message.y} button=#{message.button} action=#{message.action}"
    end
    [self, nil]
  end

  def view
    "mouse: #{@log.join(' | ')}"
  end
end

Bubbletea.run(App.new, mouse_cell_motion: true)

__END__
size: 70x4
steps:
  - snapshot: start
  - input: "\e[<0;5;3M"
    snapshot: press
  - input: "\e[<0;5;3m"
    snapshot: release
  - keys: [q]
    exit: true
