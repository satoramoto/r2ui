# Alt screen: a line replaced by a shorter one has no leftover characters from the old text.
require "bubbletea"

VIEWS = ["a long line of text\nsecond line here", "short\nx"].freeze

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
size: 30x6
steps:
  - snapshot: long
  - keys: [n]
    snapshot: short
