# Setting shorter content while scrolled past its end clamps the offset to the new bottom.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @vp = Bubbles::Viewport.new(width: 20, height: 4)
    @vp.content = (1..20).map { |i| format("long %02d", i) }.join("\n")
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "s"
      @vp.content = (1..6).map { |i| format("short %d", i) }.join("\n")
    else
      @vp, command = @vp.update(message)
    end
    [self, command]
  end

  def view = "#{@vp.view}\ny=#{@vp.y_offset} total=#{@vp.total_line_count} bottom=#{@vp.at_bottom?}"
end

Bubbletea.run(App.new)

__END__
size: 30x8
steps:
  - keys: [G]
    snapshot: at_bottom
  - keys: [s]
    snapshot: replaced
