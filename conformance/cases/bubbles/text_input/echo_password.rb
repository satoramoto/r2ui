# ECHO_PASSWORD masks every character with the echo character ("*" by default).
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.echo_mode = Bubbles::TextInput::ECHO_PASSWORD
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
  - keys: [s, e, c, r, e, t]
    snapshot: typed
  - keys: [left, left]
    snapshot: cursor_on_mask
