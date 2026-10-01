# A timer that was never started (no init) ignores tick messages and returns no command.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @timer = Bubbles::Timer.new(62.0)
    @note = "none"
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "t"
      @timer, command = @timer.update(Bubbles::Timer::TickMessage.new(id: 0, tag: 0))
      @note = command.nil? ? "no-cmd" : "cmd"
    end
    [self, nil]
  end

  def view = "#{@timer.view} #{@note}"
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - keys: [t]
    snapshot: ignored
