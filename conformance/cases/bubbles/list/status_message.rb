# set_status_message shows a status line under the list (after a blank line); show_status_bar = false hides it.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @c = Bubbles::List.new(%w[Apple Banana Cherry Date], width: 30, height: 8)
    @c.status_message_lifetime = 600.0
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage)
      case message.to_s
      when "s" then return [self, @c.set_status_message("Saved!")]
      when "h" then @c.show_status_bar = false; return [self, nil]
      end
    end
    @c, command = @c.update(message)
    [self, command]
  end

  def view = @c.view
end

Bubbletea.run(Host.new)

__END__
size: 30x12
steps:
  - snapshot: before
  - keys: [s]
    wait_for: "Saved!"
    snapshot: with_status
  - keys: [h]
    snapshot: hidden
