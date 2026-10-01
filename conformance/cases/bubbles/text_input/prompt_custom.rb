# A custom prompt string replaces the default "> ".
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.prompt = "Name: "
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
  end

  def init = [self, nil]

  def update(message)
    @input, command = @input.update(message)
    [self, command]
  end

  def view = @input.view
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - snapshot: start
  - keys: [A, d, a]
    snapshot: typed
