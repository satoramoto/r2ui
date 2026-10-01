# Typing and enter build up multiple lines; unused rows show the "~" end-of-buffer marker.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 20, height: 4)
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
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
size: 30x8
steps:
  - snapshot: start
  - keys: [a, b]
    snapshot: ab
  - keys: [enter, c]
    snapshot: two_lines
  - keys: [enter, enter, d]
    snapshot: four_lines
