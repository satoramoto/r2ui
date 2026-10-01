# key_style, desc_style and separator_style color each part of short help separately.
require "bubbletea"
require "bubbles"
require "lipgloss"

class Keys
  A = Bubbles::Key.binding(keys: %w[a], help: ["a", "add"])
  B = Bubbles::Key.binding(keys: %w[b], help: ["b", "back"])
  C = Bubbles::Key.binding(keys: %w[c], help: ["c", "copy"])

  def short_help = [A, B, C]
  def full_help = [[A, B], [C]]
end

class Host
  include Bubbletea::Model

  def initialize
    @h = Bubbles::Help.new
    @h.key_style = Lipgloss::Style.new.bold(true).foreground("#FFAA00")
    @h.desc_style = Lipgloss::Style.new.foreground("#888888")
    @h.separator_style = Lipgloss::Style.new.foreground("#444444")
    @keys = Keys.new
  end

  def init = [self, nil]

  def update(message)
    @h.show_all = true if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "f"
    [self, nil]
  end

  def view = @h.view(@keys)
end

Bubbletea.run(Host.new)

__END__
size: 50x4
steps:
  - snapshot: short
  - keys: [f]
    snapshot: full
