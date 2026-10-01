# A full-help group with no visible bindings contributes no column.
require "bubbletea"
require "bubbles"

class Keys
  A = Bubbles::Key.binding(keys: %w[a], help: ["a", "alpha"])
  OFF = Bubbles::Key.binding(keys: %w[x], help: ["x", "off"], enabled: false)
  B = Bubbles::Key.binding(keys: %w[b], help: ["b", "beta"])

  def full_help = [[A], [OFF], [B]]
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
  - snapshot: two_columns
