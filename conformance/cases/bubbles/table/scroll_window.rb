# With more rows than height, moving past the window scrolls it by one row; the header stays put.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    rows = (1..10).map { |i| ["Row #{i}", (i * 10).to_s] }
    @t = Bubbles::Table.new(columns: [{ title: "Name", width: 10 }, { title: "Val", width: 5 }], rows: rows, height: 4)
  end

  def init = [self, nil]

  def update(message)
    @t, command = @t.update(message)
    [self, command]
  end

  def view = @t.view
end

Bubbletea.run(Host.new)

__END__
size: 30x8
steps:
  - snapshot: top
  - keys: [down, down, down]
    snapshot: last_visible
  - keys: [down]
    snapshot: scrolled_one
  - keys: [down, down, down]
    snapshot: scrolled_four
  - keys: [up, up, up, up, up]
    snapshot: scrolled_back
