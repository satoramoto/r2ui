# The model returned from init replaces the original; the replacement receives updates and draws the view.
require "bubbletea"

class Second
  include Bubbletea::Model

  def initialize
    @keys = 0
  end

  def update(message)
    return [self, nil] unless message.is_a?(Bubbletea::KeyMessage)
    return [self, Bubbletea.quit] if message.to_s == "q"

    @keys += 1
    [self, nil]
  end

  def view
    "second model, keys=#{@keys}"
  end
end

class First
  include Bubbletea::Model

  def init
    [Second.new, nil]
  end

  def view
    "first model"
  end
end

Bubbletea.run(First.new)

__END__
size: 30x5
steps:
  - snapshot: start
  - keys: [a, b]
    snapshot: two_keys
  - keys: [q]
    exit: true
