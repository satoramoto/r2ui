# Elapsed time over an hour shows "h:mm:ss.cc": 3725.25 seconds is "1:02:05.25".
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @sw = Bubbles::Stopwatch.new(interval: 3725.25)
    @sw.update(Bubbles::Stopwatch::StartStopMessage.new(id: @sw.id, running: true))
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "t"
      @sw, = @sw.update(Bubbles::Stopwatch::TickMessage.new(id: 0, tag: 0))
    end
    [self, nil]
  end

  def view = @sw.view
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - keys: [t]
    snapshot: one
  - keys: [t]
    snapshot: two
