# enter_alt_screen from update switches to the alternate screen; quitting returns to the main screen.
require "bubbletea"

class App
  include Bubbletea::Model

  def initialize
    @n = 0
  end

  def update(message)
    return [self, nil] unless message.is_a?(Bubbletea::KeyMessage)

    @n += 1
    case message.to_s
    when "a" then [self, Bubbletea.enter_alt_screen]
    when "q" then [self, Bubbletea.quit]
    else [self, nil]
    end
  end

  def view
    "view line, keys=#{@n}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - snapshot: inline
  - keys: [a]
    snapshot: alt
  - keys: [q]
    exit: true
    snapshot: after_quit
