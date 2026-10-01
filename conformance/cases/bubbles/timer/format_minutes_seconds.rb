# A 90 second timer that has not started shows "1m30s", is not running and is not timed out.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @timer = Bubbles::Timer.new(90.0)
  end

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view = "#{@timer.view} running=#{@timer.running?} out=#{@timer.timed_out?}"
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - snapshot: start
