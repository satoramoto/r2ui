# A keymap with only short_help still renders short help when show_all is set.
require "bubbletea"
require "bubbles"

class Keys
  A = Bubbles::Key.binding(keys: %w[a], help: ["a", "add"])
  B = Bubbles::Key.binding(keys: %w[b], help: ["b", "back"])

  def short_help = [A, B]
end

class Host
  include Bubbletea::Model

  def initialize
    @h = Bubbles::Help.new
    @h.show_all = true
    @keys = Keys.new
  end

  def init = [self, nil]

  def update(message) = [self, nil]

  def view = @h.view(@keys)
end

Bubbletea.run(Host.new)

__END__
size: 50x3
steps:
  - snapshot: short_fallback
