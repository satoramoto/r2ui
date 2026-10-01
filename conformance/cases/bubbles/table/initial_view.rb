# Default table: bold header, a rule of box-drawing dashes, rows padded to column widths, first row reversed.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @t = Bubbles::Table.new(
      columns: [{ title: "Name", width: 10 }, { title: "Role", width: 12 }, { title: "Age", width: 4 }],
      rows: [%w[Alice Engineer 30], %w[Bob Designer 25], %w[Carol Manager 41]],
      height: 5
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
size: 40x8
steps:
  - snapshot: start
