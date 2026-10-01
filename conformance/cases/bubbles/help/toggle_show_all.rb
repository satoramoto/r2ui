# Pressing "?" toggles show_all, switching between the short line and the full columns.
require "bubbletea"
require "bubbles"

class Keys
  UP = Bubbles::Key.binding(keys: %w[up k], help: ["↑/k", "up"])
  DOWN = Bubbles::Key.binding(keys: %w[down j], help: ["↓/j", "down"])
  HELP = Bubbles::Key.binding(keys: %w[?], help: ["?", "more"])
  QUIT = Bubbles::Key.binding(keys: %w[q], help: ["q", "quit"])

  def short_help = [HELP, QUIT]
  def full_help = [[UP, DOWN], [HELP, QUIT]]
end

class Host
  include Bubbletea::Model

  def initialize
    @h = Bubbles::Help.new
    @keys = Keys.new
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && Bubbles::Key.matches?(message, Keys::HELP)
      @h.show_all = !@h.show_all
    end
    [self, nil]
  end

  def view = @h.view(@keys)
end

Bubbletea.run(Host.new)

__END__
size: 50x4
steps:
  - snapshot: short
  - keys: ["?"]
    snapshot: full
  - keys: ["?"]
    snapshot: short_again
