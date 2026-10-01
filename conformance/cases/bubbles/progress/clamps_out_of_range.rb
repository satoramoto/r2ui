# view_as clamps percents above 1.0 to 100% and below 0.0 to 0%.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new(width: 30)
  end

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view = [@bar.view_as(1.7), @bar.view_as(-0.4)].join("\n")
end

Bubbletea.run(App.new)

__END__
size: 60x4
steps:
  - snapshot: start
