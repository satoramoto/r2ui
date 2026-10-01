# Line numbers beyond 9 use two digits in the gutter.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 20, height: 4)
    @area.show_line_numbers = true
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
    @area.value = (1..11).map { |i| "line#{i}" }.join("\n")
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
