# The README counter: inline renderer, arrow and letter keys, quit with q.
require "bubbletea"

class Counter
  include Bubbletea::Model

  def initialize
    @count = 0
  end

  def init
    [self, nil]
  end

  def update(message)
    return [self, nil] unless message.is_a?(Bubbletea::KeyMessage)

    case message.to_s
    when "q", "ctrl+c" then return [self, Bubbletea.quit]
    when "up", "k" then @count += 1
    when "down", "j" then @count -= 1
    end
    [self, nil]
  end

  def view
    "Count: #{@count}\n\nPress up/down to change, q to quit"
  end
end

Bubbletea.run(Counter.new)

__END__
size: 40x8
steps:
  - snapshot: start
  - keys: [up, up, k]
    snapshot: three
  - keys: [down, j, j, j, j]
    snapshot: negative
  - keys: [q]
    exit: true
    snapshot: quit
