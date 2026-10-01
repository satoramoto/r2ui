# Default list: title, first page of string items, selected row with reverse video, dots pagination.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @c = Bubbles::List.new(%w[Apple Banana Cherry Date Elder Fig Grape Honeydew Kiwi Lemon], width: 30, height: 8)
  end

  def init = [self, nil]

  def update(message)
    return [self, Bubbletea.quit] if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "ctrl+c"

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
