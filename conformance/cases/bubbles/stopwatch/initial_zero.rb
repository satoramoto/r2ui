# A new stopwatch shows "0:00.00" elapsed and is not running.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @sw = Bubbles::Stopwatch.new
  end

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view = "#{@sw.view} running=#{@sw.running?} elapsed=#{@sw.elapsed}"
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - snapshot: start
