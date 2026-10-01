# The stop command pauses the stopwatch: running becomes false and further ticks leave elapsed unchanged.
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
    case message
    when Bubbletea::KeyMessage
      case message.to_s
      when "t" then @sw, = @sw.update(Bubbles::Stopwatch::TickMessage.new(id: 0, tag: 0))
      when "p" then return [self, @sw.stop]
      end
    when Bubbles::Stopwatch::StartStopMessage
      @sw, = @sw.update(message)
    end
    [self, nil]
  end

  def view = "#{@sw.view} running=#{@sw.running?}"
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - keys: [t, t]
    snapshot: ticked
  - keys: [p]
    wait_for: "running=false"
    snapshot: stopped
  - keys: [t]
    snapshot: tick_ignored
