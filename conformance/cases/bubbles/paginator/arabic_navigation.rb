# next_page/prev_page advance and retreat in arabic view and stop at the ends.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @p = Bubbles::Paginator.new(per_page: 10)
    @p.update_total_pages(35)
    @last = ""
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage)
      case message.to_s
      when "n" then @last = "next=#{@p.next_page}"
      when "p" then @last = "prev=#{@p.prev_page}"
      end
    end
    [self, nil]
  end

  def view = "[#{@p.view}] page=#{@p.page} #{@last}"
end

Bubbletea.run(Host.new)

__END__
size: 40x4
steps:
  - snapshot: start
  - keys: [n, n]
    snapshot: page_three
  - keys: [n, n]
    snapshot: last_page_stops
  - keys: [p, p, p, p]
    snapshot: first_page_stops
