# scroll_percent is y_offset / (total - height): halfway through 11 lines in a 5-row viewport is 50 percent.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @vp = Bubbles::Viewport.new(width: 20, height: 5)
    @vp.content = (1..11).map { |i| format("line %02d", i) }.join("\n")
  end

  def init = [self, nil]

  def update(message)
    @vp, command = @vp.update(message)
    [self, command]
  end

  def view = "#{@vp.view}\ny=#{@vp.y_offset} pct=#{(@vp.scroll_percent * 1000).round / 10.0} total=#{@vp.total_line_count}"
end

Bubbletea.run(App.new)

__END__
size: 30x8
steps:
  - keys: [j, j, j]
    snapshot: pct_50
  - keys: [j]
    snapshot: pct_67
