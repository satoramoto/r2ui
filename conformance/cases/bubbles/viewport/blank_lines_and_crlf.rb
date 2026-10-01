# Content keeps blank lines, trailing newline as an extra empty line, and CRLF is normalised to LF.
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @vp = Bubbles::Viewport.new(width: 20, height: 4)
    @vp.content = "one\r\n\r\nthree\r\nfour\nfive\n"
  end

  def init = [self, nil]

  def update(message)
    @vp, command = @vp.update(message)
    [self, command]
  end

  def view = "#{@vp.view}\ntotal=#{@vp.total_line_count}"
end

Bubbletea.run(App.new)

__END__
size: 30x8
steps:
  - snapshot: start
  - keys: [G]
    snapshot: bottom
