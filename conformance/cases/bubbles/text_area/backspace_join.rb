# backspace at column 0 joins the line with the previous one; mid-line it deletes a character.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 20, height: 4)
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
    @area.value = "abc\ndef"
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
  - keys: [backspace]
    snapshot: char_deleted
  - keys: [home, backspace]
    snapshot: joined
  - keys: [home, backspace]
    snapshot: noop_at_buffer_start
