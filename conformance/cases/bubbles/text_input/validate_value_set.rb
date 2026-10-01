# Assigning value= also runs the validator.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.validate = ->(text) { text.length >= 3 ? nil : StandardError.new("too short") }
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
    @input.value = "ab"
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
  - snapshot: too_short
  - keys: [c]
    snapshot: long_enough
