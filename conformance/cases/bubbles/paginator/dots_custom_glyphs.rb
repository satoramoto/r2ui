# active_dot and inactive_dot replace the default glyphs.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @p = Bubbles::Paginator.new(type: Bubbles::Paginator::DOTS, per_page: 1)
    @p.active_dot = "#"
    @p.inactive_dot = "-"
    @p.update_total_pages(5)
  end

  def init = [self, nil]

  def update(message)
    @p.next_page if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "n"
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
