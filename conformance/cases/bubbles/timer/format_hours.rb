# Durations over an hour show hours, minutes and seconds: 3725 seconds is "1h2m5s", and 3600 is "1h0m0s".
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view
    [3725.0, 3600.0, 36000.0, 86399.0].map { |s| Bubbles::Timer.new(s).view }.join("\n")
  end
end

Bubbletea.run(App.new)

__END__
size: 40x6
steps:
  - snapshot: start
