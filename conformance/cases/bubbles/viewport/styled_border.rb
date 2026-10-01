# A viewport style with a rounded border and padding draws the frame and shrinks the visible content.
require "bubbletea"
require "bubbles"
require "lipgloss"

class App
  include Bubbletea::Model

  def initialize
    @vp = Bubbles::Viewport.new(width: 20, height: 6)
    @vp.style = Lipgloss::Style.new.border(:rounded).padding(0, 1)
    @vp.content = (1..20).map { |i| format("line %02d", i) }.join("\n")
  end

  def init = [self, nil]

  def update(message)
    @vp, command = @vp.update(message)
    [self, command]
  end

  def view = @vp.view
end

Bubbletea.run(App.new)

__END__
size: 30x10
steps:
  - snapshot: start
  - keys: [j, j]
    snapshot: scrolled
