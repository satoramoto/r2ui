# A blurred table ignores keys and draws no highlighted row; focus! brings both back.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    rows = %w[Alpha Bravo Charlie Delta].map { |n| [n, n.length.to_s] }
    @t = Bubbles::Table.new(columns: [{ title: "Name", width: 10 }, { title: "Len", width: 4 }], rows: rows, height: 4)
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage)
      case message.to_s
      when "x" then @t.blur; return [self, nil]
      when "y" then @t.focus!; return [self, nil]
      end
    end
    @t, command = @t.update(message)
    [self, command]
  end

  def view = "#{@t.view}\nfocused=#{@t.focused?} cursor=#{@t.cursor}"
end

Bubbletea.run(Host.new)

__END__
size: 30x9
steps:
  - keys: [down]
    snapshot: focused_moved
  - keys: [x]
    snapshot: blurred
  - keys: [down, down]
    snapshot: blurred_ignores_keys
  - keys: [y]
    snapshot: refocused
  - keys: [down]
    snapshot: moves_again
