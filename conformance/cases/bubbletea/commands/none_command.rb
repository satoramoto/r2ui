# Bubbletea.none (nil) and a plain nil command both do nothing; the model still updates.
require "bubbletea"

class App
  include Bubbletea::Model

  def initialize
    @n = 0
  end

  def init
    [self, Bubbletea.none]
  end

  def update(message)
    return [self, nil] unless message.is_a?(Bubbletea::KeyMessage)

    case message.to_s
    when "a" then @n += 1
    when "b"
      @n += 10
      return [self, Bubbletea.none]
    when "q" then return [self, Bubbletea.quit]
    end
    [self, nil]
  end

  def view
    "n=#{@n} none=#{Bubbletea.none.inspect}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - snapshot: start
  - keys: [a, b, a]
    snapshot: after
  - keys: [q]
    exit: true
