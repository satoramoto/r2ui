# Content shorter than the height is padded with "~" rows up to the height.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 12, height: 6)
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
    @area.value = "only line"
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
size: 20x8
steps:
  - snapshot: start
