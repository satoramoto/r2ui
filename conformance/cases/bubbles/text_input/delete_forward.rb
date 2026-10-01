# delete / ctrl+d remove the character under the cursor; no-op at the end.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
    @input.value = "abcde"
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
  - keys: [end, delete]
    snapshot: noop_at_end
  - keys: [home, delete]
    snapshot: first_deleted
  - keys: [right, ctrl+d]
    snapshot: ctrl_d
