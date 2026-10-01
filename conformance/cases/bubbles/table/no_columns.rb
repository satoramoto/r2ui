# A table with no columns renders nothing at all.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @t = Bubbles::Table.new(columns: [], rows: [["a"], ["b"]], height: 3)
  end

  def init = [self, nil]

  def update(message) = [self, nil]

  def view = "top\n[#{@t.view}]\nbottom"
end

Bubbletea.run(Host.new)

__END__
size: 20x5
steps:
  - snapshot: nothing
