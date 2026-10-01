# Moving the cursor back through scrolled text scrolls the window left again.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.width = 5
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
    @input.value = "0123456789"
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
  - snapshot: at_end
  - keys: [left, left, left, left, left]
    snapshot: still_in_window
  - keys: [left, left]
    snapshot: scrolled_left
  - keys: [home]
    snapshot: at_start
