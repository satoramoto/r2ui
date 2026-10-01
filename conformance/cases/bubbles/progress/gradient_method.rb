# Calling #gradient after construction switches a solid bar to a gradient (named hex colours, no percent text).
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new(width: 20)
    @bar.show_percentage = false
    @bar.gradient("#00ff00", "#ffff00")
  end

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view = @bar.view_as(0.75)
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - snapshot: start
