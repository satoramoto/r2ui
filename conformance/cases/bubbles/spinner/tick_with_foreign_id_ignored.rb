# A tick message for a different spinner id is ignored: the frame does not advance and no command comes back.
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
      @spinner, command = @spinner.update(Bubbles::Spinner::TickMessage.new(id: @spinner.id + 1000, tag: 0))
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
  - keys: [t]
    snapshot: ignored
