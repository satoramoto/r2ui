# left at column 0 wraps to the end of the previous line; right at line end wraps to the next line start.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 20, height: 4)
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
    @area.value = "abc\nde"
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
  - keys: [home, left]
    snapshot: wrapped_up
  - keys: [right]
    snapshot: wrapped_down
  - keys: [right, right]
    snapshot: line_end
  - keys: [right]
    snapshot: noop_at_buffer_end
