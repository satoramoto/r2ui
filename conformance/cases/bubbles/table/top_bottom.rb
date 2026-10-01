# End/G jump to the last row (window scrolls to show it); home/g jump back to the first.
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
  - keys: [end]
    snapshot: end
  - keys: [home]
    snapshot: home
  - keys: [G]
    snapshot: capital_g
  - keys: [g]
    snapshot: lower_g
