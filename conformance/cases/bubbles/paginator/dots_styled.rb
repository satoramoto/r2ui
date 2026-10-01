# active_dot_style and inactive_dot_style color the dots.
require "bubbletea"
require "bubbles"
require "lipgloss"

class Host
  include Bubbletea::Model

  def initialize
    @p = Bubbles::Paginator.new(type: Bubbles::Paginator::DOTS, per_page: 1)
    @p.active_dot_style = Lipgloss::Style.new.foreground("#FF0000").bold(true)
    @p.inactive_dot_style = Lipgloss::Style.new.foreground("#555555")
    @p.update_total_pages(4)
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
  - keys: [n]
    snapshot: second
