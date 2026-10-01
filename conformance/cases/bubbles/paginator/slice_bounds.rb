# slice_bounds and items_on_page describe the current page, with a short final page.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @p = Bubbles::Paginator.new(per_page: 10)
    @p.update_total_pages(25)
  end

  def init = [self, nil]

  def update(message)
    @p.next_page if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "n"
    [self, nil]
  end

  def view
    "page=#{@p.page} bounds=#{@p.slice_bounds(25).inspect} count=#{@p.items_on_page(25)} empty=#{@p.items_on_page(0)}"
  end
end

Bubbletea.run(Host.new)

__END__
size: 60x3
steps:
  - snapshot: first
  - keys: [n]
    snapshot: second
  - keys: [n]
    snapshot: last
