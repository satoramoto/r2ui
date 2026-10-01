# PgDown/f/space move a full height down, PgUp/b a full height up (clamped at the ends).
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    rows = (1..12).map { |i| ["Row #{i}", (i * 10).to_s] }
    @t = Bubbles::Table.new(columns: [{ title: "Name", width: 10 }, { title: "Val", width: 5 }], rows: rows, height: 4)
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
size: 30x9
steps:
  - keys: [pgdown]
    snapshot: pgdown
  - keys: [f]
    snapshot: f
  - keys: [space]
    snapshot: space_clamped
  - keys: [pgup]
    snapshot: pgup
  - keys: [b]
    snapshot: b
  - keys: [b]
    snapshot: b_clamped
