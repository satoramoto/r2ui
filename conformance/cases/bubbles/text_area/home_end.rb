# home/end move to the start/end of the current line only.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 20, height: 4)
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
    @area.value = "first\nsecond line"
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
  - keys: [home]
    snapshot: home
  - keys: [up, end]
    snapshot: end_of_first
  - keys: [ctrl+a]
    snapshot: ctrl_a
  - keys: [ctrl+e]
    snapshot: ctrl_e
