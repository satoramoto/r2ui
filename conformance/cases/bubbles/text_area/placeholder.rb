# An empty text area shows the placeholder on the first row; typing replaces it.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 20, height: 3)
    @area.placeholder = "Write something"
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
  end

  def init = [self, nil]

  def update(message)
    @area, command = @area.update(message)
    [self, command]
  end

  def view = @area.view
end

Bubbletea.run(App.new)

__END__
size: 30x6
steps:
  - snapshot: start
  - keys: [x]
    snapshot: typed
  - keys: [backspace]
    snapshot: placeholder_again
