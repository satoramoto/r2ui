# Without a horizontal step, left/right do nothing and long lines are cut to the width.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @vp = Bubbles::Viewport.new(width: 10, height: 3)
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
  - keys: [right, l]
    snapshot: after_right
