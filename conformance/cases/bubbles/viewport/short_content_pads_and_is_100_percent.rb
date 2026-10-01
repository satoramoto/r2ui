# Content shorter than the viewport is padded with blank rows, never scrolls, and reports 100 percent.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @vp = Bubbles::Viewport.new(width: 20, height: 5)
    @vp.content = "alpha\nbeta"
  end

  def init = [self, nil]

  def update(message)
    @vp, command = @vp.update(message)
    [self, command]
  end

  def view = "#{@vp.view}\ny=#{@vp.y_offset} pct=#{(@vp.scroll_percent * 100).round} visible=#{@vp.visible_line_count}"
end

Bubbletea.run(App.new)

__END__
size: 30x8
steps:
  - snapshot: start
  - keys: [j, pgdown]
    snapshot: after_scroll
