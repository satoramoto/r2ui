# left/right move the cursor, inserting mid-text, and stop at both ends.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
    @input.value = "abcd"
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
  - snapshot: start
  - keys: [left, left]
    snapshot: left_two
  - keys: [X]
    snapshot: inserted
  - keys: [left, left, left, left, left, left]
    snapshot: clamped_left
  - keys: [right, right, right, right, right, right, right, right]
    snapshot: clamped_right
