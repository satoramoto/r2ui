# Moving the cursor above the first visible line scrolls the viewport back up.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 20, height: 3)
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
    @area.value = "l1\nl2\nl3\nl4\nl5\nl6"
  end

  def init = [self, nil]

  def update(message)
    @area, command = @area.update(message)
    [self, command]
  end

  def view = "#{@area.view}\nrow=#{@area.row}"
end

Bubbletea.run(App.new)

__END__
size: 30x6
steps:
  - snapshot: at_bottom
  - keys: [up, up]
    snapshot: inside_window
  - keys: [up]
    snapshot: scrolled_up_one
  - keys: [up, up, up]
    snapshot: at_top
