# Disabled bindings, and bindings without help text, are left out of both short and full help.
require "bubbletea"
require "bubbles"

class Keys
  A = Bubbles::Key.binding(keys: %w[a], help: ["a", "shown"])
  OFF = Bubbles::Key.binding(keys: %w[x], help: ["x", "disabled"], enabled: false)
  NOHELP = Bubbles::Key.binding(keys: %w[n])
  B = Bubbles::Key.binding(keys: %w[b], help: ["b", "also shown"])

  def short_help = [A, OFF, NOHELP, B]
  def full_help = [[A, OFF], [NOHELP, B]]
end

class Host
  include Bubbletea::Model

  def initialize
    @h = Bubbles::Help.new
    @keys = Keys.new
  end

  def init = [self, nil]

  def update(message)
    @h.show_all = true if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "f"
    [self, nil]
  end

  def view = @h.view(@keys)
end

Bubbletea.run(Host.new)

__END__
size: 50x4
steps:
  - snapshot: short
  - keys: [f]
    snapshot: full
