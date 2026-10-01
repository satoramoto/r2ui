# The validate callback runs on every change; its error is exposed via #error.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.validate = ->(text) { text.match?(/\A\d*\z/) ? nil : StandardError.new("digits only") }
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
  end

  def init = [self, nil]

  def update(message)
    @input, command = @input.update(message)
    [self, command]
  end

  def view = "#{@input.view}\nerror=#{@input.error ? @input.error.message : 'none'}"
end

Bubbletea.run(App.new)

__END__
size: 40x4
steps:
  - snapshot: start
  - keys: ["1", "2"]
    snapshot: valid
  - keys: [x]
    snapshot: invalid
  - keys: [backspace]
    snapshot: valid_again
