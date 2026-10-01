# A table with fewer rows than its height still occupies height + 2 lines (blank padding rows follow).
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    @t = Bubbles::Table.new(columns: [{ title: "Name", width: 10 }], rows: [["One"], ["Two"]], height: 5)
  end

  def init = [self, nil]

  def update(message) = [self, nil]

  def view = "#{@t.view}\n--end--"
end

Bubbletea.run(Host.new)

__END__
size: 20x10
steps:
  - snapshot: padded
