# Columns of different heights: shorter columns contribute empty cells on the later rows.
require "bubbletea"
require "bubbles"

class Keys
  A = Bubbles::Key.binding(keys: %w[a], help: ["a", "one"])
  B = Bubbles::Key.binding(keys: %w[b], help: ["b", "two"])
  C = Bubbles::Key.binding(keys: %w[c], help: ["c", "three"])
  D = Bubbles::Key.binding(keys: %w[d], help: ["d", "four"])
  E = Bubbles::Key.binding(keys: %w[e], help: ["e", "five"])

  def full_help = [[A, B, C], [D], [E, A]]
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
size: 50x5
steps:
  - snapshot: uneven
