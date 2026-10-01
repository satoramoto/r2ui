# Ticks for another id, or with a positive tag not matching the stopwatch's tag, are ignored; start/stop for another id too.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @sw = Bubbles::Stopwatch.new(interval: 0.5)
    @sw.update(Bubbles::Stopwatch::StartStopMessage.new(id: @sw.id, running: true))
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage)
      msg = case message.to_s
            when "f" then Bubbles::Stopwatch::TickMessage.new(id: @sw.id + 1000, tag: 0)
            when "s" then Bubbles::Stopwatch::TickMessage.new(id: @sw.id, tag: 9)
            when "x" then Bubbles::Stopwatch::StartStopMessage.new(id: @sw.id + 1000, running: false)
            when "m" then Bubbles::Stopwatch::TickMessage.new(id: @sw.id, tag: 0)
            end
      @sw, = @sw.update(msg) if msg
    end
    [self, nil]
  end

  def view = "#{@sw.view} running=#{@sw.running?}"
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - keys: [f]
    snapshot: foreign_tick_ignored
  - keys: [s]
    snapshot: stale_tag_ignored
  - keys: [x]
    snapshot: foreign_stop_ignored
  - keys: [m]
    snapshot: matching_counts
