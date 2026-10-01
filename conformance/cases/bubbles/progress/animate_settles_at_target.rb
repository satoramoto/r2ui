# set_percent(0.5) animates with frame messages; once it settles the bar shows exactly 50% and is no longer animating.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new(width: 30)
  end

  def init = [self, @bar.set_percent(0.5)]

  def update(message)
    return [self, nil] unless message.is_a?(Bubbles::Progress::FrameMessage)

    @bar, command = @bar.update(message)
    [self, command]
  end

  def view = "#{@bar.view}\ntarget=#{@bar.percent} animating=#{@bar.animating?}"
end

Bubbletea.run(App.new)

__END__
size: 40x4
steps:
  - wait_for: "animating=false"
    snapshot: settled
