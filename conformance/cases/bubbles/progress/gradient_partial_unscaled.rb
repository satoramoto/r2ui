# An unscaled gradient at 50 percent only reaches halfway between the colours; the rest of the bar is empty.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new(width: 24, gradient: ["#ff0000", "#0000ff"])
  end

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view = @bar.view_as(0.5)
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - snapshot: start
