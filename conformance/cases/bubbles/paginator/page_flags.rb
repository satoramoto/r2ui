# prev_page? and next_page? report whether there is a page before/after the current one.
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

  def view = "page=#{@p.page} prev?=#{@p.prev_page?} next?=#{@p.next_page?}"
end

Bubbletea.run(Host.new)

__END__
size: 50x3
steps:
  - snapshot: first
  - keys: [n]
    snapshot: middle
  - keys: [n]
    snapshot: last
