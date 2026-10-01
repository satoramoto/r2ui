# ctrl+k deletes to the end of the line and ctrl+u to the start of the line, within the current line.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 20, height: 4)
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
    @area.value = "keep this\nhello world\nkeep too"
  end

  def init = [self, nil]

  def update(message)
    @area, command = @area.update(message)
    [self, command]
  end

  def view = "#{@area.view}\nrow=#{@area.row} col=#{@area.col}"
end

Bubbletea.run(App.new)

__END__
size: 30x7
steps:
  - keys: [up, home, right, right, right, right, right]
    snapshot: placed
  - keys: [ctrl+k]
    snapshot: killed_to_end
  - keys: [ctrl+u]
    snapshot: killed_to_start
