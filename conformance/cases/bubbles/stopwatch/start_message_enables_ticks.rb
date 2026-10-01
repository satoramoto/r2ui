# A start/stop message with running true enables ticks; each tick adds one interval (0.25s) and returns a next-tick command.
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
    if message.is_a?(Bubbletea::KeyMessage)
      case message.to_s
      when "s" then @sw, = @sw.update(Bubbles::Stopwatch::StartStopMessage.new(id: @sw.id, running: true))
      when "t"
        @sw, command = @sw.update(Bubbles::Stopwatch::TickMessage.new(id: 0, tag: 0))
        @note = command.nil? ? "no-cmd" : "cmd"
      end
    end
    [self, nil]
  end

  def view = "#{@sw.view} running=#{@sw.running?} #{@note}"
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - keys: [s]
    snapshot: started
  - keys: [t]
    snapshot: tick1
  - keys: [t, t, t]
    snapshot: tick4
