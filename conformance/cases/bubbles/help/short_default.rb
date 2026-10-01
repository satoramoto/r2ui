# Short help joins "key desc" pairs with the default " • " separator.
require "bubbletea"
require "bubbles"

class Keys
  UP = Bubbles::Key.binding(keys: %w[up k], help: ["↑/k", "up"])
  DOWN = Bubbles::Key.binding(keys: %w[down j], help: ["↓/j", "down"])
  QUIT = Bubbles::Key.binding(keys: %w[q], help: ["q", "quit"])

  def short_help = [UP, DOWN, QUIT]
  def full_help = [[UP, DOWN], [QUIT]]
end

class Host
  include Bubbletea::Model

  def initialize
    @h = Bubbles::Help.new
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
  - snapshot: short
