# A spinner style (bold, true-colour foreground) wraps the frame in styling.
require "bubbletea"
require "bubbles"
require "lipgloss"

class App
  include Bubbletea::Model

  def initialize
    style = Lipgloss::Style.new.bold(true).foreground("#ff5faf")
    @spinner = Bubbles::Spinner.new(spinner: Bubbles::Spinners::DOT.merge(fps: 0.02), style: style)
    @count = 0
    @limit = 3
  end

  def init = [self, @spinner.tick]

  def update(message)
    return [self, nil] unless message.is_a?(Bubbles::Spinner::TickMessage)

    @count += 1
    @spinner, command = @spinner.update(message)
    [self, @count < @limit ? command : nil]
  end

  def view = "#{@spinner.view} working ticks=#{@count}#{@count >= @limit ? ' done' : ''}"
end

Bubbletea.run(App.new)

__END__
size: 30x3
steps:
  - wait_for: "done"
    snapshot: final
