# Zero and negative durations show "0s"; fractions are truncated toward zero (59.9 is "59s", 0.9 is "0s").
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view
    [0.0, -5.0, 59.9, 0.9, 61.99].map { |s| Bubbles::Timer.new(s).view }.join("\n")
  end
end

Bubbletea.run(App.new)

__END__
size: 40x7
steps:
  - snapshot: start
