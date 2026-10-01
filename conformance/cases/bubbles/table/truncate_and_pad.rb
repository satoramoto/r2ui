# Cells longer than their column are cut with an ellipsis in the last cell; header titles obey the same rule.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @t = Bubbles::Table.new(
      columns: [{ title: "A very long title", width: 8 }, { title: "Ok", width: 6 }],
      rows: [["Short", "tiny"], ["Exactly8", "exactly"], ["Much too long cell", "x"]],
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
  - snapshot: truncated
  - keys: [end]
    snapshot: last_selected
