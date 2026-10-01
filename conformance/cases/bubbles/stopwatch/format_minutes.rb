# Elapsed time over a minute shows "m:ss.cc": a 61.5 second tick gives "1:01.50", two give "2:03.00".
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @sw = Bubbles::Stopwatch.new(interval: 61.5)
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
