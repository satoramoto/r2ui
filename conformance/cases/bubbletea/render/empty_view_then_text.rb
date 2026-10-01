# An empty view draws nothing; a later non-empty view appears, then an empty view clears it again.
require "bubbletea"

VIEWS = ["", "hello\nworld", ""].freeze

class Views
  include Bubbletea::Model

  def initialize
    @i = 0
  end

  def init = [self, nil]

  def update(message)
    return [self, nil] unless message.is_a?(Bubbletea::KeyMessage)

    case message.to_s
    when "n" then @i = [@i + 1, VIEWS.size - 1].min
    when "q" then return [self, Bubbletea.quit]
    end
    [self, nil]
  end

  def view = VIEWS[@i]
end

Bubbletea.run(Views.new, alt_screen: true)

__END__
size: 20x5
steps:
  - snapshot: empty
  - keys: [n]
    snapshot: text
  - keys: [n]
    snapshot: empty_again
