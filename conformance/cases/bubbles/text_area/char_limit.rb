# char_limit caps the total length (newlines count) and blocks further typing.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 20, height: 3)
    @area.char_limit = 5
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
  end

  def init = [self, nil]

  def update(message)
    @area, command = @area.update(message)
    [self, command]
  end

  def view = "#{@area.view}\nvalue=#{@area.value.inspect}"
end

Bubbletea.run(App.new)

__END__
size: 30x6
steps:
  - keys: [a, b, c]
    snapshot: three
  - keys: [enter, d, e, f]
    snapshot: capped
