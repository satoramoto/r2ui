# increment_percent and decrement_percent move the target by the amount, clamped to 0..1; each settles before the next key.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new(width: 30)
  end

  def init = [self, nil]

  def update(message)
    case message
    when Bubbletea::KeyMessage
      case message.to_s
      when "i" then return [self, @bar.increment_percent(0.25)]
      when "d" then return [self, @bar.decrement_percent(0.5)]
      end
    when Bubbles::Progress::FrameMessage
      @bar, command = @bar.update(message)
      return [self, command]
    end
    [self, nil]
  end

  def view = "#{@bar.view}\ntarget=#{@bar.percent} animating=#{@bar.animating?}"
end

Bubbletea.run(App.new)

__END__
size: 40x4
steps:
  - keys: [i]
    wait_for: "animating=false"
    snapshot: plus_quarter
  - keys: [i, i, i, i, i]
    wait_for: "target=1.0 animating=false"
    snapshot: clamped_one
  - keys: [d]
    wait_for: "target=0.5 animating=false"
    snapshot: minus_half
  - keys: [d, d]
    wait_for: "target=0.0 animating=false"
    snapshot: clamped_zero
