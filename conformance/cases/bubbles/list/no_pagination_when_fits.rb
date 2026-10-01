# When every item fits, no paginator is drawn and short lists are padded to the full height (fill_height).
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @c = Bubbles::List.new(%w[One Two Three], width: 30, height: 10)
    @c.title = "Short"
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "f"
      @c.fill_height = false
      return [self, nil]
    end
    @c, command = @c.update(message)
    [self, command]
  end

  def view = @c.view + "\n--end--"
end

Bubbletea.run(Host.new)

__END__
size: 30x14
steps:
  - snapshot: filled
  - keys: [f]
    snapshot: not_filled
