# Custom full and empty characters replace the block glyphs.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new(width: 30)
    @bar.full = "#"
    @bar.empty = "-"
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
