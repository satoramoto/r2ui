# ctrl+b / ctrl+f move the cursor left / right like the arrow keys.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
    @input.value = "abcdef"
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
  - keys: [ctrl+b, ctrl+b, ctrl+b]
    snapshot: back_three
  - keys: [ctrl+f]
    snapshot: forward_one
