# Alt screen mode: sixty messages fired from init at once settle on the final state of the view.
require "bubbletea"

class Bump < Bubbletea::Message; end

class Rapid
  include Bubbletea::Model

  def initialize
    @n = 0
  end

  def init = [self, Bubbletea.batch(*Array.new(60) { Bubbletea.send_message(Bump.new) })]

  def update(message)
    @n += 1 if message.is_a?(Bump)
    return [self, Bubbletea.quit] if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "q"

    [self, nil]
  end

  def view = "count: #{@n}\n#{'#' * [@n % 20, 1].max}"
end

Bubbletea.run(Rapid.new, alt_screen: true)

__END__
size: 30x6
steps:
  - wait_for: "count: 60"
    snapshot: sixty
