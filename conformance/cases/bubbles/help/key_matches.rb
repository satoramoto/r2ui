# Key.matches? matches a KeyMessage against any key of any enabled binding; disabled bindings never match.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  UP = Bubbles::Key.binding(keys: %w[up k], help: ["↑/k", "up"])
  QUIT = Bubbles::Key.binding(keys: %w[q ctrl+x], help: ["q", "quit"])
  OFF = Bubbles::Key.binding(keys: %w[z], help: ["z", "off"], enabled: false)

  def initialize
    @log = []
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage)
      tags = []
      tags << "UP" if Bubbles::Key.matches?(message, UP)
      tags << "QUIT" if Bubbles::Key.matches?(message, QUIT)
      tags << "OFF" if Bubbles::Key.matches?(message, OFF)
      tags << "EITHER" if Bubbles::Key.matches?(message, UP, QUIT)
      @log << "#{message}: #{tags.join(',')}"
    end
    [self, nil]
  end

  def view = @log.join("\n")
end

Bubbletea.run(Host.new)

__END__
size: 40x8
steps:
  - keys: [up, k, q, ctrl+x, z, x]
    snapshot: matches
