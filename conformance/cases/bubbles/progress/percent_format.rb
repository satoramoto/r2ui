# A custom percent_format is applied to percent * 100 and its rendered length reduces the bar width.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new(width: 30)
    @bar.percent_format = " [%5.1f%%]"
  end

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view = @bar.view_as(0.425)
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - snapshot: start
