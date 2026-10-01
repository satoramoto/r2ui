# The startup WindowSizeMessage is the same in the alt screen, and the view can fill the whole height.
require "bubbletea"

class App
  include Bubbletea::Model

  def initialize
    @w = 0
    @h = 0
  end

  def update(message)
    case message
    when Bubbletea::WindowSizeMessage
      @w = message.width
      @h = message.height
    when Bubbletea::KeyMessage then return [self, Bubbletea.quit] if message.to_s == "q"
    end
    [self, nil]
  end

  def view
    rows = Array.new(@h) { |i| i.zero? ? "top #{@w}x#{@h}" : (i == @h - 1 ? "bottom" : "") }
    rows.join("\n")
  end
end

Bubbletea.run(App.new, alt_screen: true)

__END__
size: 36x7
steps:
  - snapshot: start
  - keys: [q]
    exit: true
