# header_style, cell_style and selected_style replace the default bold header, plain cells and reverse selection.
require "bubbletea"
require "bubbles"
require "lipgloss"

class Host
  include Bubbletea::Model

  def initialize
    @t = Bubbles::Table.new(
      columns: [{ title: "Name", width: 8 }, { title: "Qty", width: 4 }],
      rows: [%w[Bolt 100], %w[Nut 250], %w[Washer 75]],
      height: 4
    )
    @t.header_style = Lipgloss::Style.new.foreground("#FFD700").underline(true)
    @t.cell_style = Lipgloss::Style.new.foreground("#AAAAAA")
    @t.selected_style = Lipgloss::Style.new.background("#0000AA").foreground("#FFFFFF").bold(true)
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
  - snapshot: start
  - keys: [down]
    snapshot: moved
