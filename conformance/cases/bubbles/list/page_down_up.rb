# PgDown/PgUp (and ctrl+f/ctrl+b) move the selection by one page of visible items.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @c = Bubbles::List.new((1..20).map { |i| "Item #{i}" }, width: 30, height: 8)
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
  - keys: [pgdown]
    snapshot: pgdown
  - keys: [pgdown]
    snapshot: pgdown_again
  - keys: [pgup]
    snapshot: pgup
  - keys: [ctrl+f]
    snapshot: ctrl_f
  - keys: [ctrl+b, ctrl+b, ctrl+b]
    snapshot: ctrl_b_to_top
