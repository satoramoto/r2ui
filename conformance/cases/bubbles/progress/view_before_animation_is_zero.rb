# #view (as opposed to view_as) renders the animated current value, which starts at 0 percent.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new(width: 30)
  end

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view = "#{@bar.view}\ntarget=#{@bar.percent} animating=#{@bar.animating?}"
end

Bubbletea.run(App.new)

__END__
size: 40x4
steps:
  - snapshot: start
