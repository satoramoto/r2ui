# A 0 percent bar at width 40 is all empty cells followed by "  0%".
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new
  end

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view = @bar.view_as(0.0)
end

Bubbletea.run(App.new)

__END__
size: 60x3
steps:
  - snapshot: start
