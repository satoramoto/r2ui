# up/down move between lines, clamping the column to the shorter line, and stop at the first/last line.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 20, height: 5)
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
    @area.value = "long line here\nab\nmedium line"
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
size: 30x8
steps:
  - snapshot: start
  - keys: [up]
    snapshot: up_clamped
  - keys: [up, up, up]
    snapshot: top
  - keys: [down, down, down, down]
    snapshot: bottom
