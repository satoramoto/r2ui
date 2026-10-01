# A 50 percent bar fills half of the bar area (width minus the percent text) with the default purple.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new
  end

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view = @bar.view_as(0.5)
end

Bubbletea.run(App.new)

__END__
size: 60x3
steps:
  - snapshot: start
