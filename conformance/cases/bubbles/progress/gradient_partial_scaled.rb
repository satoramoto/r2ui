# A scaled gradient at 50 percent stretches the full colour range across just the filled part.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new(width: 24, scaled_gradient: ["#ff0000", "#0000ff"])
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
