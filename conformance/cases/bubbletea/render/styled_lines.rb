# Styled lines: bold, colour and background runs land on the right cells, plain lines stay plain.
require "bubbletea"
require "lipgloss"

BOLD = Lipgloss::Style.new.bold(true)
RED = Lipgloss::Style.new.foreground("#FF0000")
BG = Lipgloss::Style.new.background("#0000FF").foreground("#FFFFFF")

VIEWS = [
  [BOLD.render("bold"), "plain", "x #{RED.render('red')} y", BG.render(" on blue "), ""].join("\n")
].freeze

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
