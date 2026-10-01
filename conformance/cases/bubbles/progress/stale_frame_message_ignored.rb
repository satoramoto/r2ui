# A frame message with a foreign id does nothing: no state change and no follow-up command.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @bar = Bubbles::Progress.new(width: 30)
    @note = "none"
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "f"
      @bar.set_percent(0.8)
      @bar, command = @bar.update(Bubbles::Progress::FrameMessage.new(id: @bar.id + 1000, tag: 1))
      @note = command.nil? ? "no-cmd" : "cmd"
    end
    [self, nil]
  end

  def view = "#{@bar.view}\ntarget=#{@bar.percent} #{@note}"
end

Bubbletea.run(App.new)

__END__
size: 40x4
steps:
  - keys: [f]
    snapshot: ignored
