# With a positive width, each full-help row is cut to that many characters independently.
require "bubbletea"
require "bubbles"

class Keys
  A = Bubbles::Key.binding(keys: %w[a], help: ["a", "add item"])
  B = Bubbles::Key.binding(keys: %w[b], help: ["b", "go back"])
  C = Bubbles::Key.binding(keys: %w[c], help: ["c", "copy it"])
  D = Bubbles::Key.binding(keys: %w[d], help: ["d", "dd"])

  def full_help = [[A, B], [C, D]]
end

class Host
  include Bubbletea::Model

  def initialize
    @h = Bubbles::Help.new
    @h.show_all = true
    @h.width = 18
    @keys = Keys.new
  end

  def init = [self, nil]

  def update(message) = [self, nil]

  def view = @h.view(@keys)
end

Bubbletea.run(Host.new)

__END__
size: 50x4
steps:
  - snapshot: cut_at_18
