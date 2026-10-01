# With height 3, moving the cursor below the last visible line scrolls the viewport down.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 20, height: 3)
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
  end

  def init = [self, nil]

  def update(message)
    @area, command = @area.update(message)
    [self, command]
  end

  def view = "#{@area.view}\nrow=#{@area.row} lines=#{@area.line_count}"
end

Bubbletea.run(App.new)

__END__
size: 30x6
steps:
  - keys: [a, enter, b, enter, c]
    snapshot: exactly_full
  - keys: [enter, d]
    snapshot: scrolled_one
  - keys: [enter, e, enter, f]
    snapshot: scrolled_three
