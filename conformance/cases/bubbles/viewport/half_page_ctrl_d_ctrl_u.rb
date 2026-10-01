# ctrl+d scrolls half a page down (height / 2, rounded down) and ctrl+u half a page up.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @vp = Bubbles::Viewport.new(width: 20, height: 5)
    @vp.content = (1..20).map { |i| format("line %02d", i) }.join("\n")
  end

  def init = [self, nil]

  def update(message)
    @vp, command = @vp.update(message)
    [self, command]
  end

  def view = "#{@vp.view}\ny=#{@vp.y_offset} pct=#{(@vp.scroll_percent * 100).round} top=#{@vp.at_top?} bottom=#{@vp.at_bottom?}"
end

Bubbletea.run(App.new)

__END__
size: 44x8
steps:
  - keys: [ctrl+d, ctrl+d]
    snapshot: half_twice
  - keys: [ctrl+u]
    snapshot: half_up
