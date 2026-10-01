# The start command first sends a start message (running becomes true) and then schedules a tick; the tick is 100s away so only the start is observed.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @sw = Bubbles::Stopwatch.new(interval: 100.0)
  end

  def init = [self, nil]

  def update(message)
    case message
    when Bubbletea::KeyMessage
      return [self, @sw.start] if message.to_s == "s"
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
  - snapshot: start
  - keys: [s]
    wait_for: "running=true"
    snapshot: started
