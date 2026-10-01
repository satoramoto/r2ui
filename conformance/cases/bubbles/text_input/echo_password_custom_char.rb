# echo_character replaces the default "*" mask.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.echo_mode = Bubbles::TextInput::ECHO_PASSWORD
    @input.echo_character = "•"
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
  end

  def init = [self, nil]

  def update(message)
    @input, command = @input.update(message)
    [self, command]
  end

  def view = "#{@input.view}\nvalue=[#{@input.value}]"
end

Bubbletea.run(App.new)

__END__
size: 40x4
steps:
  - keys: [p, i, n]
    snapshot: typed
