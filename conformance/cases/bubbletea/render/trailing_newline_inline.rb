# Inline mode: a view ending in a newline draws an extra blank line after the text.
require "bubbletea"

VIEWS = ["one\ntwo\n"].freeze

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
size: 20x6
steps:
  - snapshot: start
  - keys: [q]
    exit: true
    snapshot: after_quit
