# full_color and empty_color set the foreground of the filled and empty runs.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new(width: 30)
    @bar.full_color = "#ff0000"
    @bar.empty_color = "#0000ff"
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
