# With line numbers on, the placeholder row is indented by the gutter width.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 24, height: 3)
    @area.show_line_numbers = true
    @area.placeholder = "Type here"
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
size: 30x5
steps:
  - snapshot: start
  - keys: [a]
    snapshot: typed
