# Suggestion matching ignores case; the suggestion's own casing fills the remainder.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.show_suggestions = true
    @input.suggestions = %w[Banana Berry]
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
  - keys: [b, a]
    snapshot: ba
  - keys: [tab]
    snapshot: accepted
