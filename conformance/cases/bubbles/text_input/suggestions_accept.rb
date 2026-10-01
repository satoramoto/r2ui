# tab accepts the current suggestion, replacing the value and moving the cursor to the end.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.show_suggestions = true
    @input.suggestions = %w[apple apricot banana]
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
  end

  def init = [self, nil]

  def update(message)
    @input, command = @input.update(message)
    [self, command]
  end

  def view = "#{@input.view}\nvalue=[#{@input.value}] pos=#{@input.position}"
end

Bubbletea.run(App.new)

__END__
size: 40x4
steps:
  - keys: [b, a]
    snapshot: ba
  - keys: [tab]
    snapshot: accepted
