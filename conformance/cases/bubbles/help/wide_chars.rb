# Unicode key labels (arrows, bullet separator) render in short help without disturbing the row.
require "bubbletea"
require "bubbles"

class Keys
  NAV = Bubbles::Key.binding(keys: %w[left right], help: ["←/→", "navigate"])
  ENTER = Bubbles::Key.binding(keys: %w[enter], help: ["↵", "confirm"])
  ESC = Bubbles::Key.binding(keys: %w[esc], help: ["⎋", "cancel"])

  def short_help = [NAV, ENTER, ESC]
end

class Host
  include Bubbletea::Model

  def initialize
    @h = Bubbles::Help.new
    @keys = Keys.new
  end

  def init = [self, nil]

  def update(message) = [self, nil]

  def view = "#{@h.view(@keys)}|"
end

Bubbletea.run(Host.new)

__END__
size: 60x3
steps:
  - snapshot: unicode
