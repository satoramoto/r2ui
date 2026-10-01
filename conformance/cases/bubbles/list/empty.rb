# A list with no items shows "No items" under the title and ignores navigation keys.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @c = Bubbles::List.new([], width: 30, height: 8)
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
  - snapshot: start
  - keys: [down, end, pgdown]
    snapshot: after_keys
