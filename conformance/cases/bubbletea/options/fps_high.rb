# fps: 120 is accepted; every key is reflected in the screen once idle.
require "bubbletea"

class App
  include Bubbletea::Model

  def initialize
    @n = 0
  end

  def update(message)
    return [self, nil] unless message.is_a?(Bubbletea::KeyMessage)
    return [self, Bubbletea.quit] if message.to_s == "q"

    @n += 1
    [self, nil]
  end

  def view
    "presses: #{@n}"
  end
end

Bubbletea.run(App.new, fps: 120)

__END__
size: 30x4
steps:
  - snapshot: start
  - keys: [a, b, c, d]
    snapshot: four
  - keys: [q]
    exit: true
