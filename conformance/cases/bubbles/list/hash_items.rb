# Hash items render their :title; descriptions are not drawn by the default row renderer.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    items = [
      { title: "Raspberry Pi", description: "Small computer" },
      { title: "Arduino", description: "Microcontroller" },
      { title: "Teensy", description: "Fast microcontroller" }
    ]
    @c = Bubbles::List.new(items, width: 30, height: 8)
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
  - keys: [down]
    snapshot: second
  - keys: ["/", a, r]
    snapshot: filtered
