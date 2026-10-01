# One page: arabic shows 1/1, dots show a single filled dot, and navigation does nothing.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @a = Bubbles::Paginator.new(per_page: 10)
    @d = Bubbles::Paginator.new(type: Bubbles::Paginator::DOTS, per_page: 10)
    [@a, @d].each { |p| p.update_total_pages(4) }
  end

  def init = [self, nil]

  def update(message)
    [@a, @d].each(&:next_page) if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "n"
    [self, nil]
  end

  def view = "arabic: #{@a.view}\ndots: #{@d.view}"
end

Bubbletea.run(Host.new)

__END__
size: 40x4
steps:
  - snapshot: start
  - keys: [n]
    snapshot: after_next
