# With mouse_all_motion, motion with no button pressed is reported as a motion MouseMessage.
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
      @log << "x=#{message.x} y=#{message.y} motion=#{message.motion?}"
    end
    [self, nil]
  end

  def view
    "move: #{@log.join(' | ')}"
  end
end

Bubbletea.run(App.new, mouse_all_motion: true)

__END__
size: 60x4
steps:
  - snapshot: start
  - input: "\e[<35;12;7M"
    snapshot: moved
  - keys: [q]
    exit: true
