# update_total_pages rounds up (and never goes below one page, even for zero items).
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @rows = [0, 1, 10, 11, 20, 21, 99, 100].map do |n|
      p = Bubbles::Paginator.new(per_page: 10)
      p.update_total_pages(n)
      "#{n} items -> #{p.total_pages} (#{p.view})"
    end
  end

  def init = [self, nil]

  def update(message) = [self, nil]

  def view = @rows.join("\n")
end

Bubbletea.run(Host.new)

__END__
size: 40x10
steps:
  - snapshot: totals
