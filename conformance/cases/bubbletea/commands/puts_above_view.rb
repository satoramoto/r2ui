# puts prints a line above the live view when not in the alt screen; the view stays at the bottom.
require "bubbletea"

class App
  include Bubbletea::Model

  def initialize
    @n = 0
  end

  def update(message)
    return [self, nil] unless message.is_a?(Bubbletea::KeyMessage)

    case message.to_s
    when "p"
      @n += 1
      [self, Bubbletea.puts("printed #{@n}")]
    when "q" then [self, Bubbletea.quit]
    else [self, nil]
    end
  end

  def view
    "view n=#{@n}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x8
steps:
  - snapshot: start
  - keys: [p]
    snapshot: one
  - keys: [p, p]
    snapshot: three
  - keys: [q]
    exit: true
    snapshot: quit
