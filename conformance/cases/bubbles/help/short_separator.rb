# short_separator replaces the " • " between short-help entries.
require "bubbletea"
require "bubbles"

class Keys
  A = Bubbles::Key.binding(keys: %w[a], help: ["a", "add"])
  B = Bubbles::Key.binding(keys: %w[b], help: ["b", "back"])
  C = Bubbles::Key.binding(keys: %w[c], help: ["c", "copy"])

  def short_help = [A, B, C]
end

class Host
  include Bubbletea::Model

  def initialize
    @h = Bubbles::Help.new
    @h.short_separator = " | "
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
  - snapshot: pipes
