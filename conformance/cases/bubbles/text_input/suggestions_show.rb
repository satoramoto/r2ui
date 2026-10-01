# With show_suggestions, the remainder of the first matching suggestion is shown after the cursor.
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

  def view = "#{@input.view}\nvalue=[#{@input.value}]"
end

Bubbletea.run(App.new)

__END__
size: 40x4
steps:
  - snapshot: empty
  - keys: [a]
    snapshot: a
  - keys: [p, r]
    snapshot: apr
  - keys: [x]
    snapshot: no_match
