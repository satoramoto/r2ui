# home/ctrl+a jump to the start, end/ctrl+e to the end of the text.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
    @input.value = "hello world"
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
  - keys: [home]
    snapshot: home
  - keys: [end]
    snapshot: end
  - keys: [ctrl+a]
    snapshot: ctrl_a
  - keys: [ctrl+e]
    snapshot: ctrl_e
