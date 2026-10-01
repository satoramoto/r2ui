# key_style styles the whole arabic "page/total" text.
require "bubbletea"
require "bubbles"
require "lipgloss"

class Host
  include Bubbletea::Model

  def initialize
    @p = Bubbles::Paginator.new(per_page: 10)
    @p.key_style = Lipgloss::Style.new.foreground("#00AAFF").italic(true)
    @p.update_total_pages(30)
  end

  def init = [self, nil]

  def update(message) = [self, nil]

  def view = @p.view
end

Bubbletea.run(Host.new)

__END__
size: 40x3
steps:
  - snapshot: styled
