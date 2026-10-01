# Many pages: dots are not collapsed, one per page, and the line is not wrapped within the width.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @p = Bubbles::Paginator.new(type: Bubbles::Paginator::DOTS, per_page: 1)
    @p.update_total_pages(20)
    @p.go_to_page(12)
  end

  def init = [self, nil]

  def update(message) = [self, nil]

  def view = @p.view
end

Bubbletea.run(Host.new)

__END__
size: 50x3
steps:
  - snapshot: twenty_dots
