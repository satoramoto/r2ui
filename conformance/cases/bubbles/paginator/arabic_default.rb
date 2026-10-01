# Default paginator is arabic: "page/total", one-based, with a single page before any items are counted.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @p = Bubbles::Paginator.new
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "t"
      @p.update_total_pages(95)
    end
    [self, nil]
  end

  def view = "[#{@p.view}] type=#{@p.type} per_page=#{@p.per_page}"
end

Bubbletea.run(Host.new)

__END__
size: 40x4
steps:
  - snapshot: initial
  - keys: [t]
    snapshot: ninety_five_items
