# Assigning items= resets the filter and selection and redraws with the new items.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @c = Bubbles::List.new(%w[Apple Banana Cherry Date], width: 30, height: 8)
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "r"
      @c.items = %w[Red Green Blue]
      return [self, nil]
    end
    @c, command = @c.update(message)
    [self, command]
  end

  def view = "#{@c.view}\nsel=#{@c.selected_index} n=#{@c.items.length}"
end

Bubbletea.run(Host.new)

__END__
size: 30x12
steps:
  - keys: [down, down]
    snapshot: moved
  - keys: [r]
    snapshot: replaced
