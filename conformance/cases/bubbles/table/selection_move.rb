# Down/up and j/k move the highlighted row one at a time and clamp at both ends.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    rows = %w[Alpha Bravo Charlie Delta Echo].map { |n| [n, n.length.to_s] }
    @t = Bubbles::Table.new(columns: [{ title: "Name", width: 10 }, { title: "Len", width: 4 }], rows: rows, height: 5)
  end

  def init = [self, nil]

  def update(message)
    @t, command = @t.update(message)
    [self, command]
  end

  def view = "#{@t.view}\ncursor=#{@t.cursor} row=#{@t.selected_row_data.inspect}"
end

Bubbletea.run(Host.new)

__END__
size: 40x10
steps:
  - keys: [down, down]
    snapshot: two_down
  - keys: [up]
    snapshot: one_up
  - keys: [j, j, j, j, j]
    snapshot: clamped_bottom
  - keys: [k, k, k, k, k, k, k]
    snapshot: clamped_top
