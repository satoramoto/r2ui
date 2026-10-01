# full_separator replaces the spacing between full-help columns; rows are not padded to align.
require "bubbletea"
require "bubbles"

class Keys
  A = Bubbles::Key.binding(keys: %w[a], help: ["a", "add"])
  B = Bubbles::Key.binding(keys: %w[b], help: ["bbbb", "back up a long way"])
  C = Bubbles::Key.binding(keys: %w[c], help: ["c", "copy"])
  D = Bubbles::Key.binding(keys: %w[d], help: ["d", "delete"])

  def full_help = [[A, B], [C, D]]
end

class Host
  include Bubbletea::Model

  def initialize
    @h = Bubbles::Help.new
    @h.show_all = true
    @h.full_separator = " :: "
    @keys = Keys.new
  end

  def init = [self, nil]

  def update(message) = [self, nil]

  def view = @h.view(@keys)
end

Bubbletea.run(Host.new)

__END__
size: 60x4
steps:
  - snapshot: custom_columns
