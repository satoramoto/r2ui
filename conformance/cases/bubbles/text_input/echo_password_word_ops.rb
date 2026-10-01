# In password mode ctrl+w deletes everything before the cursor and alt+b jumps to the start, not by word.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.echo_mode = Bubbles::TextInput::ECHO_PASSWORD
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
    @input.value = "ab cd ef"
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
  - input: "\eb"
    snapshot: word_back_goes_to_start
  - keys: [end, left, left]
    snapshot: moved
  - keys: [ctrl+w]
    snapshot: ctrl_w_clears_prefix
