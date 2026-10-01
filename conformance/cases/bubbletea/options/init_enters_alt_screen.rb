# init returning enter_alt_screen starts the program on the alternate screen (no alt_screen option).
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
    return [self, Bubbletea.quit] if message.to_s == "q"

    @n += 1
    [self, nil]
  end

  def view
    "started in alt, keys=#{@n}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - keys: [x]
    snapshot: running
  - keys: [q]
    exit: true
    snapshot: after_quit
