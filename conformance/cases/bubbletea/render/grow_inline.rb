# Inline mode: a view that grows from one line to four draws the new lines below.
require "bubbletea"

VIEWS = ["a1", "b1\nb2\nb3\nb4"].freeze

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

Bubbletea.run(Views.new)

__END__
size: 20x10
steps:
  - snapshot: one
  - keys: [n]
    snapshot: four
