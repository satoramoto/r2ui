# The toggle command flips running to stopped and back (the restart schedules a tick 100s away, never reached).
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @timer = Bubbles::Timer.new(62.0, interval: 100.0)
    @timer.init
  end

  def init = [self, nil]

  def update(message)
    case message
    when Bubbletea::KeyMessage
      return [self, @timer.toggle] if message.to_s == "g"
    when Bubbles::Timer::StartStopMessage
      @timer, = @timer.update(message)
    end
    [self, nil]
  end

  def view = "#{@timer.view} running=#{@timer.running?}"
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
