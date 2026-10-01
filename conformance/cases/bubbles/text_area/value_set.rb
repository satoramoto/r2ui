# Assigning a multi-line value splits on newlines and puts the cursor at the very end.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 20, height: 5)
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
    @area.value = "one\ntwo\n\nfour"
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
  - keys: ["!"]
    snapshot: appended
