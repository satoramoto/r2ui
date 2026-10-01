# A custom spinner hash with its own frames and fps is honoured, including multi-character frames.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @spinner = Bubbles::Spinner.new(spinner: { frames: ["a", "bb", "ccc", "dddd"], fps: 0.02 })
    @count = 0
    @limit = 6
  end

  def init = [self, @spinner.tick]

  def update(message)
    return [self, nil] unless message.is_a?(Bubbles::Spinner::TickMessage)

    @count += 1
    @spinner, command = @spinner.update(message)
    [self, @count < @limit ? command : nil]
  end

  def view = "[#{@spinner.view}] ticks=#{@count}#{@count >= @limit ? ' done' : ''}"
end

Bubbletea.run(App.new)

__END__
size: 30x3
steps:
  - wait_for: "done"
    snapshot: final
