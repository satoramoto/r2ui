# Moving the selection past the visible window scrolls it one row at a time; the dots track the page.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @c = Bubbles::List.new((1..12).map { |i| "Item #{i}" }, width: 30, height: 8)
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
  - keys: [down, down, down]
    snapshot: last_visible
  - keys: [down]
    snapshot: scrolled_one
  - keys: [down, down, down, down]
    snapshot: scrolled_five
  - keys: [up, up, up, up, up, up, up, up]
    snapshot: back_up
