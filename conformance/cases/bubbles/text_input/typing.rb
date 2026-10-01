# Typing characters appends them after the default "> " prompt and advances the cursor.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
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
  - snapshot: start
  - keys: [h, i]
    snapshot: hi
  - keys: [space, t, h, e, r, e]
    snapshot: hi_there
