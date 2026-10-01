# After init the timer runs; each tick message (id 0, tag 0 wildcard) subtracts one interval (1s here).
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
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "t"
      @timer, = @timer.update(Bubbles::Timer::TickMessage.new(id: 0, tag: 0))
    end
    [self, nil]
  end

  def view = "#{@timer.view} running=#{@timer.running?} out=#{@timer.timed_out?}"
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - snapshot: start
  - keys: [t]
    snapshot: one
  - keys: [t, t]
    snapshot: three
