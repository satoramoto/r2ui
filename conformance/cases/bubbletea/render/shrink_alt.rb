# Alt screen: a view that shrinks from five lines to two clears the leftover lines.
require "bubbletea"

VIEWS = ["a1\na2\na3\na4\na5", "b1\nb2"].freeze

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
size: 20x10
steps:
  - snapshot: five
  - keys: [n]
    snapshot: two
