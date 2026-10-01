# A gradient with exactly one filled cell uses the midpoint colour of the two ends.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new(width: 24, gradient: ["#ff0000", "#0000ff"])
    @bar.show_percentage = false
  end

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view = @bar.view_as(1.0 / 24)
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - snapshot: start
