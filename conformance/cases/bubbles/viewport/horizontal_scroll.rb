# With a horizontal step set, right/left scroll columns and wide lines are cut to the viewport width.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @vp = Bubbles::Viewport.new(width: 10, height: 3)
    @vp.horizontal_step = 4
    @vp.content = "0123456789ABCDEFGHIJ\nabcdefghijklmnopqrst\nshort"
  end

  def init = [self, nil]

  def update(message)
    @vp, command = @vp.update(message)
    [self, command]
  end

  def view = "#{@vp.view}\nx=#{@vp.x_offset}"
end

Bubbletea.run(App.new)

__END__
size: 30x8
steps:
  - snapshot: start
  - keys: [right]
    snapshot: right1
  - keys: [l, l, l]
    snapshot: clamped_right
  - keys: [left]
    snapshot: left1
