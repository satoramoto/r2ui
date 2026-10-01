# A plain line replaced by a styled one on the same row picks up the styling.
require "bubbletea"
require "lipgloss"

ITALIC = Lipgloss::Style.new.italic(true).underline(true).foreground("#FFAA00")

VIEWS = ["plain line\ntail", "#{ITALIC.render('now styled')}\ntail"].freeze

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
  - snapshot: plain
  - keys: [n]
    snapshot: styled
