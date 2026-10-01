# title_style, item_style and selected_item_style render the title and rows with lipgloss styles.
require "bubbletea"
require "bubbles"
require "lipgloss"

class Host
  include Bubbletea::Model

  def initialize
    @c = Bubbles::List.new(%w[Apple Banana Cherry Date], width: 30, height: 8)
    @c.title = "Styled"
    @c.title_style = Lipgloss::Style.new.bold(true).foreground("#FF8700")
    @c.item_style = Lipgloss::Style.new.foreground("#888888")
    @c.selected_item_style = Lipgloss::Style.new.bold(true).foreground("#00FF00")
  end

  def init = [self, nil]

  def update(message)
    @c, command = @c.update(message)
    [self, command]
  end

  def view = @c.view
end

Bubbletea.run(Host.new)

__END__
size: 30x10
steps:
  - snapshot: start
  - keys: [down]
    snapshot: moved
