# Inline mode: quitting after the view shrank leaves only the smaller final frame on screen.
require "bubbletea"

VIEWS = ["a1\na2\na3\na4", "last\nframe"].freeze

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
size: 30x8
steps:
  - snapshot: start
  - keys: [n]
    snapshot: shrunk
  - keys: [q]
    exit: true
    snapshot: after_quit
