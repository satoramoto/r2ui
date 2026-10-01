# With more items than fit, a dots paginator appears below the rows; show_pagination = false hides it.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @c = Bubbles::List.new((1..30).map { |i| "Item #{i}" }, width: 30, height: 8)
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "p"
      @c.show_pagination = false
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
  - snapshot: first_page
  - keys: [pgdown, pgdown]
    snapshot: third_page
  - keys: [end]
    snapshot: last_page
  - keys: [p]
    snapshot: no_pagination
