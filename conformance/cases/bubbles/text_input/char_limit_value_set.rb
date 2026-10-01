# Assigning a value longer than char_limit truncates it to the limit.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.char_limit = 4
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
    @input.value = "abcdefgh"
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
  - snapshot: truncated
