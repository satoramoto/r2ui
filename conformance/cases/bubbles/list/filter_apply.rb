# Enter applies the filter: the input is blurred but stays visible and navigation works on the filtered items.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @c = Bubbles::List.new(%w[Apple Banana Cherry Date Elder Fig Grape Honeydew Kiwi Lemon], width: 30, height: 10)
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
size: 30x12
steps:
  - keys: ["/", e, r]
    snapshot: typing
  - keys: [enter]
    snapshot: applied
  - keys: [down]
    snapshot: moved
  - keys: [j]
    snapshot: moved_again
