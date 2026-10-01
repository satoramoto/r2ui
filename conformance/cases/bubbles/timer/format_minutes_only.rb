# Exact minutes keep a zero seconds part ("2m0s"), and sub-minute values omit the minutes part ("45s").
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view
    [120.0, 60.0, 45.0, 1.0, 600.0].map { |s| Bubbles::Timer.new(s).view }.join("\n")
  end
end

Bubbletea.run(App.new)

__END__
size: 40x7
steps:
  - snapshot: start
