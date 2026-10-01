# Counting down across the one hour boundary drops the hours part: 1h0m0s then 59m59s.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @timer = Bubbles::Timer.new(3601.0)
    @timer.init
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "t"
      @timer, = @timer.update(Bubbles::Timer::TickMessage.new(id: 0, tag: 0))
    end
    [self, nil]
  end

  def view = @timer.view
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - snapshot: start
  - keys: [t]
    snapshot: exact_hour
  - keys: [t]
    snapshot: below_hour
