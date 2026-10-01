# Down/up and j/k move the selection one row at a time.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @c = Bubbles::List.new(%w[Apple Banana Cherry Date Elder Fig Grape Honeydew Kiwi Lemon], width: 30, height: 8)
  end

  def init = [self, nil]

  def update(message)
    @c, command = @c.update(message)
    [self, command]
  end

  def view = @c.view
end

Bubbletea.run(Host.new)

__END__
size: 30x10
steps:
  - keys: [down, down]
    snapshot: two_down
  - keys: [up]
    snapshot: one_up
  - keys: [j, j]
    snapshot: j_twice
  - keys: [k]
    snapshot: k_once
  - keys: [up, up, up, up, up]
    snapshot: clamped_at_top
