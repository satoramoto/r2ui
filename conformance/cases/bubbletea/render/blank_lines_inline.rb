# Inline mode: leading, middle and trailing blank lines in a view are kept as blank rows.
require "bubbletea"

VIEWS = ["\ntop\n\n\nbottom\n\n"].freeze

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
  - snapshot: start
