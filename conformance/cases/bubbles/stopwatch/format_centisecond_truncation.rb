# Centiseconds are truncated from the float remainder: 0.29 seconds renders ".28" and 0.07 renders ".07"; whole seconds roll over.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view
    [0.29, 0.07, 0.999, 9.5, 59.99, 60.0].map do |step|
      sw = Bubbles::Stopwatch.new(interval: step)
      sw.update(Bubbles::Stopwatch::StartStopMessage.new(id: sw.id, running: true))
      sw, = sw.update(Bubbles::Stopwatch::TickMessage.new(id: 0, tag: 0))
      "#{step} -> #{sw.view}"
    end.join("\n")
  end
end

Bubbletea.run(App.new)

__END__
size: 40x8
steps:
  - snapshot: start
