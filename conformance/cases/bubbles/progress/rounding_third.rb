# Filled cell count is rounded (not floored) and the percent text is rounded to a whole number: 1/3 and 2/3.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new
  end

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view = [@bar.view_as(1.0 / 3), @bar.view_as(2.0 / 3), @bar.view_as(0.07), @bar.view_as(0.995)].join("\n")
end

Bubbletea.run(App.new)

__END__
size: 60x6
steps:
  - snapshot: start
