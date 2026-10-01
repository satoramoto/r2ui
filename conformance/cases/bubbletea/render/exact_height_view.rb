# Alt screen: a view with exactly as many lines as the screen has rows fills it with nothing cut.
require "bubbletea"

VIEWS = [(1..5).map { |n| "row #{n}" }.join("\n")].freeze

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
  - snapshot: start
