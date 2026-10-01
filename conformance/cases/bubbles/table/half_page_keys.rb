# ctrl+d/d move half a height down, ctrl+u/u half a height up.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    rows = (1..14).map { |i| ["Row #{i}", (i * 10).to_s] }
    @t = Bubbles::Table.new(columns: [{ title: "Name", width: 10 }, { title: "Val", width: 5 }], rows: rows, height: 6)
  end

  def init = [self, nil]

  def update(message)
    @t, command = @t.update(message)
    [self, command]
  end

  def view = "#{@t.view}\ncursor=#{@t.cursor}"
end

Bubbletea.run(Host.new)

__END__
size: 30x11
steps:
  - keys: [ctrl+d]
    snapshot: ctrl_d
  - keys: [d, d]
    snapshot: d_d
  - keys: [ctrl+u]
    snapshot: ctrl_u
  - keys: [u]
    snapshot: u
