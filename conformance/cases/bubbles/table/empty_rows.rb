# A table with columns but no rows shows the header, rule and a "No data" line.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @t = Bubbles::Table.new(columns: [{ title: "Name", width: 10 }, { title: "Age", width: 5 }], rows: [], height: 4)
  end

  def init = [self, nil]

  def update(message)
    @t, command = @t.update(message)
    [self, command]
  end

  def view = "#{@t.view}\nrow=#{@t.selected_row_data.inspect}"
end

Bubbletea.run(Host.new)

__END__
size: 30x8
steps:
  - snapshot: empty
  - keys: [down, end, pgdown]
    snapshot: after_keys
