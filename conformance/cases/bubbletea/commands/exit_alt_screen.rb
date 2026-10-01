# exit_alt_screen from update leaves an alt_screen: true program on the main screen.
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
    when "x" then [self, Bubbletea.exit_alt_screen]
    when "q" then [self, Bubbletea.quit]
    else [self, nil]
    end
  end

  def view
    "view line, keys=#{@n}"
  end
end

Bubbletea.run(App.new, alt_screen: true)

__END__
size: 30x5
steps:
  - snapshot: alt
  - keys: [x]
    snapshot: main
  - keys: [q]
    exit: true
    snapshot: after_quit
