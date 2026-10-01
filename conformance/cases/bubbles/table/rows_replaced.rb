# Assigning rows= keeps the cursor when it is still valid and clamps it (scrolling the window) when not.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    rows = (1..10).map { |i| ["Row #{i}"] }
    @t = Bubbles::Table.new(columns: [{ title: "Name", width: 10 }], rows: rows, height: 4)
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "r"
      @t.rows = [["New 1"], ["New 2"]]
      return [self, nil]
    end
    @t, command = @t.update(message)
    [self, command]
  end

  def view = "#{@t.view}\ncursor=#{@t.cursor}"
end

Bubbletea.run(Host.new)

__END__
size: 30x9
steps:
  - keys: [end]
    snapshot: at_last
  - keys: [r]
    snapshot: replaced_shorter
