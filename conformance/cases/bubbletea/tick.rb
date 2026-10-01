# Timer-driven updates: ticks every 50ms, stops after five and quits on its own. Snapshots wait
# for screen text, so timing never decides what is captured.
require "bubbletea"

class Tick < Bubbletea::Message; end

class Ticker
  include Bubbletea::Model

  def initialize
    @ticks = 0
  end

  def init
    [self, schedule]
  end

  def update(message)
    case message
    when Tick
      @ticks += 1
      return [self, schedule] if @ticks < 5

      [self, Bubbletea.quit]
    when Bubbletea::KeyMessage
      message.to_s == "q" ? [self, Bubbletea.quit] : [self, nil]
    else
      [self, nil]
    end
  end

  def view
    "ticks: #{@ticks}#{@ticks == 5 ? ' (done)' : ''}"
  end

  private

  def schedule
    Bubbletea.tick(0.05) { Tick.new }
  end
end

Bubbletea.run(Ticker.new)

__END__
size: 30x5
steps:
  - wait_for: "ticks: 5 (done)"
    exit: true
    snapshot: done
