# show_line_numbers adds a right-aligned "NN " gutter to each line, and "   ~" rows for empty space.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 24, height: 5)
    @area.show_line_numbers = true
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
    @area.value = "alpha\nbeta\ngamma"
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
  - keys: [enter, d]
    snapshot: fourth_line
