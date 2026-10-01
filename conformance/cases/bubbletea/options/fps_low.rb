# fps: 2 is accepted; the final render on exit still shows the last model state.
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

Bubbletea.run(App.new, fps: 2)

__END__
size: 30x4
steps:
  - keys: [a, b, c]
  - keys: [q]
    exit: true
    snapshot: final
