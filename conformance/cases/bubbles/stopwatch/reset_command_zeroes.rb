# The reset command sets elapsed back to zero but leaves the stopwatch running.
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
      when "z" then return [self, @sw.reset]
      end
    when Bubbles::Stopwatch::ResetMessage
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
  - keys: [t, t, t]
    snapshot: one_and_half
  - keys: [z]
    wait_for: "0:00.00"
    snapshot: reset
  - keys: [t]
    snapshot: after_reset_tick
