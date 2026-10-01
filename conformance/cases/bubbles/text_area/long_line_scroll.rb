# A line longer than the width scrolls horizontally to keep the cursor visible (no wrapping).
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 10, height: 3)
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
    @area.value = "0123456789ABCDEF"
  end

  def init = [self, nil]

  def update(message)
    @area, command = @area.update(message)
    [self, command]
  end

  def view = "#{@area.view}\ncol=#{@area.col}"
end

Bubbletea.run(App.new)

__END__
size: 20x6
steps:
  - snapshot: at_end
  - keys: [home]
    snapshot: at_start
