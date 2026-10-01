# down/up cycle through matching suggestions (wrapping); tab accepts the selected one.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.show_suggestions = true
    @input.suggestions = %w[apple apricot avocado]
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
  end

  def init = [self, nil]

  def update(message)
    @input, command = @input.update(message)
    [self, command]
  end

  def view = "#{@input.view}\nvalue=[#{@input.value}]"
end

Bubbletea.run(App.new)

__END__
size: 40x4
steps:
  - keys: [a]
    snapshot: first
  - keys: [down]
    snapshot: second
  - keys: [down, down]
    snapshot: wrapped_to_first
  - keys: [up]
    snapshot: wrapped_to_last
  - keys: [tab]
    snapshot: accepted_last
