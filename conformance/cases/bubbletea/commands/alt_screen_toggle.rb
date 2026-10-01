# enter then exit alt screen round trip, entered from init via a batch, then toggled by key.
require "bubbletea"

class App
  include Bubbletea::Model

  def initialize
    @n = 0
  end

  def init
    [self, Bubbletea.enter_alt_screen]
  end

  def update(message)
    return [self, nil] unless message.is_a?(Bubbletea::KeyMessage)

    @n += 1
    case message.to_s
    when "x" then [self, Bubbletea.exit_alt_screen]
    when "a" then [self, Bubbletea.enter_alt_screen]
    when "q" then [self, Bubbletea.quit]
    else [self, nil]
    end
  end

  def view
    "toggle demo, keys=#{@n}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - snapshot: from_init
  - keys: [x]
    snapshot: left
  - keys: [a]
    snapshot: back
  - keys: [q]
    exit: true
