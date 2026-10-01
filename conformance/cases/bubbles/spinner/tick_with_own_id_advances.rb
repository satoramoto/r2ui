# A tick message carrying the spinner's own id and the current tag advances one frame and schedules the next tick (returns a command).
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @spinner = Bubbles::Spinner.new(spinner: Bubbles::Spinners::LINE)
    @note = "none"
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "t"
      @spinner, command = @spinner.update(Bubbles::Spinner::TickMessage.new(id: @spinner.id, tag: 0))
      @note = command.nil? ? "no-cmd" : "cmd"
    end
    [self, nil]
  end

  def view = "[#{@spinner.view}] #{@note}"
end

Bubbletea.run(App.new)

__END__
size: 30x3
steps:
  - snapshot: start
  - keys: [t]
    snapshot: advanced
