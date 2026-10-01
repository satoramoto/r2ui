# A custom title replaces "List"; show_title = false removes the title and its blank line.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @c = Bubbles::List.new(%w[Apple Banana Cherry Date], width: 30, height: 8)
    @c.title = "Fruits"
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "t"
      @c.show_title = !@c.show_title
      return [self, nil]
    end
    @c, command = @c.update(message)
    [self, command]
  end

  def view = @c.view
end

Bubbletea.run(Host.new)

__END__
size: 30x10
steps:
  - snapshot: titled
  - keys: [t]
    snapshot: untitled
  - keys: [t]
    snapshot: titled_again
