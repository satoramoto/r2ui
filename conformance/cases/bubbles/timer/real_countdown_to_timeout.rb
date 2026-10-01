# A short real countdown (0.3s in 0.1s ticks) reaches "0s", stops running, reports timed out and sends the timeout message.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @timer = Bubbles::Timer.new(0.3, interval: 0.1)
    @timeout = false
  end

  def init = [self, @timer.init]

  def update(message)
    case message
    when Bubbles::Timer::TickMessage, Bubbles::Timer::StartStopMessage
      @timer, command = @timer.update(message)
      [self, command]
    when Bubbles::Timer::TimeoutMessage
      @timeout = true
      [self, Bubbletea.quit]
    else
      [self, nil]
    end
  end

  def view = "#{@timer.view} running=#{@timer.running?} out=#{@timer.timed_out?} timeout_msg=#{@timeout}"
end

Bubbletea.run(App.new)

__END__
size: 50x3
steps:
  - wait_for: "timeout_msg=true"
    exit: true
    snapshot: done
