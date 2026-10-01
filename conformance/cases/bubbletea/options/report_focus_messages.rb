# With report_focus, focus-in and focus-out sequences arrive as FocusMessage and BlurMessage.
require "bubbletea"

class App
  include Bubbletea::Model

  def initialize
    @log = []
  end

  def update(message)
    case message
    when Bubbletea::KeyMessage then return [self, Bubbletea.quit] if message.to_s == "q"
    when Bubbletea::FocusMessage then @log << "focus"
    when Bubbletea::BlurMessage then @log << "blur"
    end
    [self, nil]
  end

  def view
    "events: #{@log.join(',')}"
  end
end

Bubbletea.run(App.new, report_focus: true)

__END__
size: 40x4
steps:
  - snapshot: start
  - input: "\e[O"
    snapshot: blurred
  - input: "\e[I"
    snapshot: focused
  - keys: [q]
    exit: true
