# Suggestions are not shown unless show_suggestions is true, even when suggestions are set.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.suggestions = %w[apple apricot]
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
    snapshot: a
  - keys: [tab]
    snapshot: tab_does_nothing
