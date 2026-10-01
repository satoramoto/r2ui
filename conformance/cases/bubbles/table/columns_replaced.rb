# Assigning columns= (hashes or Column structs) redraws header, rule and cells with the new widths.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @t = Bubbles::Table.new(
      columns: [{ title: "Name", width: 10 }, { title: "Role", width: 10 }],
      rows: [%w[Alice Engineer], %w[Bob Designer]],
      height: 3
    )
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "c"
      @t.columns = [Bubbles::Table::Column.new(title: "N", width: 3), { title: "Role", width: 6 }]
      return [self, nil]
    end
    @t, command = @t.update(message)
    [self, command]
  end

  def view = @t.view
end

Bubbletea.run(Host.new)

__END__
size: 30x7
steps:
  - snapshot: wide
  - keys: [c]
    snapshot: narrow
