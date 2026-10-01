# arabic_format customises the arabic text (format string receives page, total_pages).
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @p = Bubbles::Paginator.new(per_page: 5)
    @p.arabic_format = "Page %d of %d"
    @p.update_total_pages(22)
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
