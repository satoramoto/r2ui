# A gradient across a 100 percent bar runs from the first colour to the second across the whole bar, cell by cell.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new(width: 24, gradient: ["#ff0000", "#0000ff"])
  end

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view = @bar.view_as(1.0)
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - snapshot: start
