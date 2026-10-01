# delete removes the character under the cursor; at line end it pulls the next line up.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 20, height: 4)
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
    @area.value = "abc\ndef\nghi"
  end

  def init = [self, nil]

  def update(message)
    @area, command = @area.update(message)
    [self, command]
  end

  def view = "#{@area.view}\nrow=#{@area.row} col=#{@area.col} lines=#{@area.line_count}"
end

Bubbletea.run(App.new)

__END__
size: 30x7
steps:
  - keys: [up, up, home, delete]
    snapshot: char_deleted
  - keys: [end, delete]
    snapshot: joined_next
