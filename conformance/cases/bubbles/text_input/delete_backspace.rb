# backspace deletes the character before the cursor, mid-text and at the end, and is a no-op at the start.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
    @input.value = "abcde"
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
  - keys: [backspace]
    snapshot: end_deleted
  - keys: [left, left, backspace]
    snapshot: middle_deleted
  - keys: [home, backspace]
    snapshot: noop_at_start
