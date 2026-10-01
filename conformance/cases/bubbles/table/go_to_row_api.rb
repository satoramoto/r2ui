# go_to_row, move_up/move_down with counts, go_to_top/bottom and page_up/page_down drive the cursor programmatically.
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
    if message.is_a?(Bubbletea::KeyMessage)
      case message.to_s
      when "1" then @t.go_to_row(6)
      when "2" then @t.go_to_row(99)
      when "3" then @t.move_up(2)
      when "4" then @t.move_down(3)
      when "5" then @t.go_to_top
      when "6" then @t.go_to_bottom
      when "7" then @t.page_up
      when "8" then @t.page_down
      end
    end
    [self, nil]
  end

  def view = "#{@t.view}\ncursor=#{@t.cursor} selected_row=#{@t.selected_row}"
end

Bubbletea.run(Host.new)

__END__
size: 30x9
steps:
  - keys: ["1"]
    snapshot: row_6
  - keys: ["2"]
    snapshot: clamped_high
  - keys: ["3"]
    snapshot: up_two
  - keys: ["5"]
    snapshot: top
  - keys: ["4"]
    snapshot: down_three
  - keys: ["8"]
    snapshot: page_down
  - keys: ["7"]
    snapshot: page_up
  - keys: ["6"]
    snapshot: bottom
