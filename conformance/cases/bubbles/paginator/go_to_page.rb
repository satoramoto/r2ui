# go_to_page jumps to a page, clamps out-of-range values, and returns whether the page changed.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @p = Bubbles::Paginator.new(per_page: 10)
    @p.update_total_pages(50)
    @last = ""
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage)
      target = { "a" => 3, "b" => 99, "c" => -5, "d" => 3 }[message.to_s]
      @last = "changed=#{@p.go_to_page(target)}" if target
    end
    [self, nil]
  end

  def view = "[#{@p.view}] page=#{@p.page} #{@last}"
end

Bubbletea.run(Host.new)

__END__
size: 40x3
steps:
  - keys: [a]
    snapshot: to_three
  - keys: [d]
    snapshot: same_page
  - keys: [b]
    snapshot: clamped_high
  - keys: [c]
    snapshot: clamped_low
