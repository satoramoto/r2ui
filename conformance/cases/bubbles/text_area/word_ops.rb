# ctrl+w deletes the previous word; alt+b / alt+f move by word within the line.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 25, height: 3)
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
    @area.value = "one two three"
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
size: 30x6
steps:
  - input: "\eb"
    snapshot: word_back
  - input: "\eb"
    snapshot: word_back_again
  - input: "\ef"
    snapshot: word_forward
  - keys: [ctrl+w]
    snapshot: deleted_word
