# The interval option sets how much each tick subtracts: 30 second steps from 3 minutes.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @timer = Bubbles::Timer.new(180.0, interval: 30.0)
    @timer.init
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "t"
      @timer, = @timer.update(Bubbles::Timer::TickMessage.new(id: 0, tag: 0))
    end
    [self, nil]
  end

  def view = "#{@timer.view} interval=#{@timer.interval}"
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - keys: [t]
    snapshot: one
  - keys: [t]
    snapshot: two
  - keys: [t, t, t, t]
    snapshot: six_is_out
