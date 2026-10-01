# The width option sets the whole line width including the percent text; try 10, 20 and 25 at 40 percent.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view
    [10, 20, 25].map { |w| Bubbles::Progress.new(width: w).view_as(0.4) }.join("\n")
  end
end

Bubbletea.run(App.new)

__END__
size: 60x5
steps:
  - snapshot: start
