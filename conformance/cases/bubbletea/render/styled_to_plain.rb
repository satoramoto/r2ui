# A styled line replaced by plain text on the same row carries no leftover styling.
require "bubbletea"
require "lipgloss"

BOLD = Lipgloss::Style.new.bold(true).foreground("#00FF00").background("#333333")

VIEWS = [[BOLD.render("styled line"), "tail"].join("\n"), "plain!\ntail"].freeze

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
  - snapshot: styled
  - keys: [n]
    snapshot: plain
