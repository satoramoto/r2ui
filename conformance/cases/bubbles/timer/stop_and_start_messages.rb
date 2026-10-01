# The stop command pauses the timer (ticks ignored, running false); the start command resumes it so ticks count again.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @timer = Bubbles::Timer.new(62.0)
    @timer.init
  end

  def init = [self, nil]

  def update(message)
    case message
    when Bubbletea::KeyMessage
      case message.to_s
      when "t" then @timer, = @timer.update(Bubbles::Timer::TickMessage.new(id: 0, tag: 0))
      when "p" then return [self, @timer.stop]
      when "r" then return [self, @timer.start]
      end
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
  - keys: [t]
    snapshot: ticked
  - keys: [p]
    snapshot: stopped
  - keys: [t]
    snapshot: tick_while_stopped
  - keys: [r]
    wait_for: "running=true"
    snapshot: restarted
