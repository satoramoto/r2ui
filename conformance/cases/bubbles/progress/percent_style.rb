# A percent_style (bold, foreground colour) styles only the trailing percent text.
require "bubbletea"
require "bubbles"
require "lipgloss"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new(width: 30)
    @bar.percent_style = Lipgloss::Style.new.bold(true).foreground("#00ff88")
  end

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view = @bar.view_as(0.6)
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - snapshot: start
