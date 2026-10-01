# A real 1.2 second countdown in 0.1s ticks ends at "0s" after sending the timeout message; the wait is on screen text.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @timer = Bubbles::Timer.new(1.2, interval: 0.1)
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

  def view = "#{@timer.view} timeout_msg=#{@timeout}"
end

Bubbletea.run(App.new)

__END__
size: 50x3
steps:
  - wait_for: "timeout_msg=true"
    exit: true
    snapshot: done
