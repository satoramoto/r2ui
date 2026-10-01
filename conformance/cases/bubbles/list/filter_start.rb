# Pressing "/" opens the filter prompt below the title; the list is unchanged until text is typed.
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
  - keys: ["/"]
    snapshot: prompt
