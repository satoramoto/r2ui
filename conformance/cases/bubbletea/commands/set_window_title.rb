# set_window_title is accepted and does not disturb the view (the title itself is not part of the screen).
require "bubbletea"

class App
  include Bubbletea::Model

  def initialize
    @titled = false
  end

  def init
    [self, Bubbletea.set_window_title("r2ui conformance")]
  end

  def update(message)
    return [self, nil] unless message.is_a?(Bubbletea::KeyMessage)

    case message.to_s
    when "t"
      @titled = true
      [self, Bubbletea.set_window_title("second title")]
    when "q" then [self, Bubbletea.quit]
    else [self, nil]
    end
  end

  def view
    "titled again: #{@titled}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - snapshot: start
  - keys: [t]
    snapshot: retitled
  - keys: [q]
    exit: true
