# A blurred text area ignores keys and keeps showing the placeholder.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 20, height: 3)
    @area.placeholder = "Notes"
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
  end

  def init = [self, nil]

  def update(message)
    @area, command = @area.update(message)
    [self, command]
  end

  def view = "#{@area.view}\nfocused=#{@area.focused?} value=[#{@area.value}]"
end

Bubbletea.run(App.new)

__END__
size: 30x6
steps:
  - snapshot: start
  - keys: [a, enter, b]
    snapshot: ignored
