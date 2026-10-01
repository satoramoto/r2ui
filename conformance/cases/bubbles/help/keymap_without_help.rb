# A keymap that responds to neither short_help nor full_help renders as an empty string.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @h = Bubbles::Help.new
  end

  def init = [self, nil]

  def update(message) = [self, nil]

  def view = "before\n[#{@h.view(Object.new)}]\nafter"
end

Bubbletea.run(Host.new)

__END__
size: 30x5
steps:
  - snapshot: empty
