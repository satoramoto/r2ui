# Accented and symbol characters in cells are padded by character count, keeping columns aligned.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @t = Bubbles::Table.new(
      columns: [{ title: "Città", width: 8 }, { title: "Temp", width: 6 }],
      rows: [["Zürich", "12°C"], ["São Paulo", "24°C"], ["Oslo", "-3°C"]],
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
  - snapshot: unicode
