# With a positive width, a short-help line longer than the width is cut to that many characters.
require "bubbletea"
require "bubbles"

class Keys
  A = Bubbles::Key.binding(keys: %w[a], help: ["a", "add item"])
  B = Bubbles::Key.binding(keys: %w[b], help: ["b", "go back"])
  C = Bubbles::Key.binding(keys: %w[c], help: ["c", "copy it"])

  def short_help = [A, B, C]
end

class Host
  include Bubbletea::Model

  def initialize
    @h = Bubbles::Help.new
    @h.width = 20
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
  - snapshot: cut_at_20
