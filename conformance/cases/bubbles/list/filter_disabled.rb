# With show_filter = false, "/" does nothing (it is not treated as filter input).
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @c = Bubbles::List.new(%w[Apple Banana Cherry Date], width: 30, height: 8)
    @c.show_filter = false
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
  - keys: ["/", a]
    snapshot: after_slash
