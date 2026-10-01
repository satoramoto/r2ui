# select/select_next/select_prev move the selection programmatically (clamped) and the window follows.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @c = Bubbles::List.new((1..12).map { |i| "Item #{i}" }, width: 30, height: 8)
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage)
      case message.to_s
      when "1" then @c.select(9)
      when "2" then @c.select(100)
      when "3" then @c.select(-4)
      when "4" then @c.select_next
      when "5" then @c.select_prev
      end
      return [self, nil]
    end
    @c, command = @c.update(message)
    [self, command]
  end

  def view = "#{@c.view}\nsel=#{@c.selected_index} item=#{@c.selected_item}"
end

Bubbletea.run(Host.new)

__END__
size: 30x14
steps:
  - keys: ["1"]
    snapshot: select_9
  - keys: ["2"]
    snapshot: select_clamped_high
  - keys: ["3"]
    snapshot: select_clamped_low
  - keys: ["4", "4"]
    snapshot: next_twice
  - keys: ["5"]
    snapshot: prev_once
