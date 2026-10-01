# A tick with a positive tag that does not match the spinner's current tag is ignored; a zero id/tag acts as a wildcard.
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
    if message.is_a?(Bubbletea::KeyMessage)
      tick = case message.to_s
             when "s" then Bubbles::Spinner::TickMessage.new(id: @spinner.id, tag: 7)
             when "w" then Bubbles::Spinner::TickMessage.new(id: 0, tag: 0)
             end
      if tick
        @spinner, command = @spinner.update(tick)
        @note = "#{message} #{command.nil? ? 'no-cmd' : 'cmd'}"
      end
    end
    [self, nil]
  end

  def view = "[#{@spinner.view}] #{@note}"
end

Bubbletea.run(App.new)

__END__
size: 30x3
steps:
  - keys: [s]
    snapshot: stale_ignored
  - keys: [w]
    snapshot: wildcard_advances
