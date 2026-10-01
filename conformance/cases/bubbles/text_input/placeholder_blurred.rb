# A blurred input still shows the placeholder, and ignores typed keys until focused.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.placeholder = "Search..."
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "tab"
      @input.focus
      return [self, nil]
    end
    @input, command = @input.update(message)
    [self, command]
  end

  def view = "#{@input.view}\nvalue=[#{@input.value}] focused=#{@input.focused?}"
end

Bubbletea.run(App.new)

__END__
size: 40x4
steps:
  - snapshot: start
  - keys: [x, y]
    snapshot: ignored_while_blurred
  - keys: [tab, x, y]
    snapshot: focused_and_typed
