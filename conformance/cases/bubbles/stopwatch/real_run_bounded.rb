# A real stopwatch (0.05s interval) started with init accumulates exactly four accepted ticks (0:00.20); the model then ignores further ticks.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @sw = Bubbles::Stopwatch.new(interval: 0.05)
    @done = false
  end

  def init = [self, @sw.init]

  def update(message)
    return [self, nil] if @done

    case message
    when Bubbles::Stopwatch::TickMessage, Bubbles::Stopwatch::StartStopMessage
      @sw, command = @sw.update(message)
      if @sw.elapsed >= 0.2
        @done = true
        return [self, nil]
      end
      [self, command]
    else
      [self, nil]
    end
  end

  def view = "#{@sw.view} running=#{@sw.running?} #{@done ? 'done' : 'counting'}"
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - wait_for: "done"
    snapshot: done
