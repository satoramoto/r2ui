# End/G jump to the last item (scrolling the window) and home/g back to the first.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @c = Bubbles::List.new(%w[Apple Banana Cherry Date Elder Fig Grape Honeydew Kiwi Lemon], width: 30, height: 8)
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
  - keys: [end]
    snapshot: end
  - keys: [home]
    snapshot: home
  - keys: [G]
    snapshot: capital_g
  - keys: [g]
    snapshot: lower_g
