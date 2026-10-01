# A stopwatch that was not started ignores tick messages (elapsed stays zero, no command returned).
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @sw = Bubbles::Stopwatch.new(interval: 0.25)
    @note = "none"
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "t"
      @sw, command = @sw.update(Bubbles::Stopwatch::TickMessage.new(id: 0, tag: 0))
      @note = command.nil? ? "no-cmd" : "cmd"
    end
    [self, nil]
  end

  def view = "#{@sw.view} #{@note}"
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - keys: [t]
    snapshot: ignored
