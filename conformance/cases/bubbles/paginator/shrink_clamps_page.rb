# Shrinking the item count clamps the current page to the new last page.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @p = Bubbles::Paginator.new(per_page: 10)
    @p.update_total_pages(100)
    @p.go_to_page(8)
  end

  def init = [self, nil]

  def update(message)
    @p.update_total_pages(35) if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "s"
    [self, nil]
  end

  def view = "[#{@p.view}] page=#{@p.page}"
end

Bubbletea.run(Host.new)

__END__
size: 40x3
steps:
  - snapshot: page_nine
  - keys: [s]
    snapshot: shrunk
