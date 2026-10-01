# When the width is smaller than the percent text, the bar area is zero cells and only the text remains.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view
    [Bubbles::Progress.new(width: 4).view_as(0.5), Bubbles::Progress.new(width: 0).view_as(1.0)].join("\n")
  end
end

Bubbletea.run(App.new)

__END__
size: 30x4
steps:
  - snapshot: start
