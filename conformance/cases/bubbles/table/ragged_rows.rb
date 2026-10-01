# Rows shorter than the column list get blank cells; extra cells beyond the columns are ignored.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @t = Bubbles::Table.new(
      columns: [{ title: "A", width: 5 }, { title: "B", width: 5 }, { title: "C", width: 5 }],
      rows: [%w[a1], %w[a2 b2 c2 extra], %w[a3 b3]],
      height: 4
    )
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
  - snapshot: ragged
  - keys: [down]
    snapshot: second
