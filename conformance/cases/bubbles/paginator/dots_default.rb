# Dots type: one dot per page separated by spaces, filled dot for the current page.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @p = Bubbles::Paginator.new(type: Bubbles::Paginator::DOTS, per_page: 10)
    @p.update_total_pages(45)
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage)
      @p.next_page if message.to_s == "n"
      @p.prev_page if message.to_s == "p"
    end
    [self, nil]
  end

  def view = @p.view
end

Bubbletea.run(Host.new)

__END__
size: 40x3
steps:
  - snapshot: first
  - keys: [n, n]
    snapshot: third
  - keys: [n, n, n]
    snapshot: clamped_last
  - keys: [p]
    snapshot: fourth
