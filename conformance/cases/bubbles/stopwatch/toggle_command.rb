# The toggle command stops a running stopwatch and starts a stopped one (interval 100s so no real tick arrives).
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @sw = Bubbles::Stopwatch.new(interval: 100.0)
    @sw.update(Bubbles::Stopwatch::StartStopMessage.new(id: @sw.id, running: true))
  end

  def init = [self, nil]

  def update(message)
    case message
    when Bubbletea::KeyMessage
      return [self, @sw.toggle] if message.to_s == "g"
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
  - keys: [g]
    wait_for: "running=false"
    snapshot: toggled_off
  - keys: [g]
    wait_for: "running=true"
    snapshot: toggled_on
