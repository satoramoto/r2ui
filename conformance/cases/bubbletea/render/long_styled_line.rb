# A styled line wider than the terminal is truncated by cell width; the style stops with it.
require "bubbletea"
require "lipgloss"

RED = Lipgloss::Style.new.bold(true).foreground("#FF0000")

VIEWS = ["#{RED.render('0123456789abcdefghijKLMNOPQRSTUVWXYZ')}\nshort"].freeze

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
size: 20x6
steps:
  - snapshot: start
