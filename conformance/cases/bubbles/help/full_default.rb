# With show_all, full help renders one column per group, rows joined with the 4-space full separator.
require "bubbletea"
require "bubbles"

class Keys
  UP = Bubbles::Key.binding(keys: %w[up k], help: ["↑/k", "up"])
  DOWN = Bubbles::Key.binding(keys: %w[down j], help: ["↓/j", "down"])
  HELP = Bubbles::Key.binding(keys: %w[?], help: ["?", "toggle help"])
  QUIT = Bubbles::Key.binding(keys: %w[q], help: ["q", "quit"])

  def short_help = [HELP, QUIT]
  def full_help = [[UP, DOWN], [HELP, QUIT]]
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
size: 50x4
steps:
  - snapshot: full
