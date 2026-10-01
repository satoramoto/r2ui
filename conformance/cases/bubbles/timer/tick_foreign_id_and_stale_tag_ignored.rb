# Ticks for another timer id, or with a positive tag not matching the timer's tag, are ignored; the matching one counts.
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
    if message.is_a?(Bubbletea::KeyMessage)
      tick = case message.to_s
             when "f" then Bubbles::Timer::TickMessage.new(id: @timer.id + 1000, tag: 0)
             when "s" then Bubbles::Timer::TickMessage.new(id: @timer.id, tag: 9)
             when "m" then Bubbles::Timer::TickMessage.new(id: @timer.id, tag: 0)
             end
      @timer, = @timer.update(tick) if tick
    end
    [self, nil]
  end

  def view = @timer.view
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - keys: [f]
    snapshot: foreign_ignored
  - keys: [s]
    snapshot: stale_ignored
  - keys: [m]
    snapshot: matching_counts
