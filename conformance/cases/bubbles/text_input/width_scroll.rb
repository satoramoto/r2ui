# With width 6, typing past the width scrolls the visible window to keep the cursor in view.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.width = 6
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
  end

  def init = [self, nil]

  def update(message)
    @input, command = @input.update(message)
    [self, command]
  end

  def view = "#{@input.view}\nvalue=[#{@input.value}] pos=#{@input.position}"
end

Bubbletea.run(App.new)

__END__
size: 40x4
steps:
  - keys: [a, b, c, d, e]
    snapshot: fits
  - keys: [f, g, h, i]
    snapshot: scrolled
