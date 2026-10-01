# A zero timeout is timed out from the start and never counts as running, even after init.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @timer = Bubbles::Timer.new(0.0)
    @command = @timer.init
  end

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view = "#{@timer.view} running=#{@timer.running?} out=#{@timer.timed_out?} cmd=#{@command.nil? ? 'none' : 'some'}"
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - snapshot: start
