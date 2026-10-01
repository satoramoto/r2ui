# alt+b / alt+f (ESC b / ESC f) move the cursor by word.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
    @input.value = "one two  three"
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
    snapshot: word_back_1
  - input: "\eb"
    snapshot: word_back_2
  - input: "\eb"
    snapshot: word_back_3
  - input: "\ef"
    snapshot: word_forward_1
  - input: "\ef"
    snapshot: word_forward_2
