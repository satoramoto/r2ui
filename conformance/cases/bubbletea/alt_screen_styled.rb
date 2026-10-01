# Alt-screen program with a lipgloss-styled view: a list with a highlighted cursor row.
# The final snapshot checks the main screen is back after quitting.
require "bubbletea"
require "lipgloss"

class Menu
  include Bubbletea::Model

  ITEMS = %w[Apples Bananas Cherries].freeze
  TITLE = Lipgloss::Style.new.bold(true).foreground("#FAFAFA").background("#7D56F4").padding(0, 1)
  SELECTED = Lipgloss::Style.new.foreground("#EE6FF8").bold(true)

  def initialize
    @cursor = 0
  end

  def init
    [self, nil]
  end

  def update(message)
    return [self, nil] unless message.is_a?(Bubbletea::KeyMessage)

    case message.to_s
    when "q" then return [self, Bubbletea.quit]
    when "down", "j" then @cursor = [@cursor + 1, ITEMS.size - 1].min
    when "up", "k" then @cursor = [@cursor - 1, 0].max
    end
    [self, nil]
  end

  def view
    rows = ITEMS.each_with_index.map do |item, i|
      i == @cursor ? SELECTED.render("> #{item}") : "  #{item}"
    end
    [TITLE.render("Fruit"), "", *rows].join("\n")
  end
end

Bubbletea.run(Menu.new, alt_screen: true)

__END__
size: 30x8
steps:
  - snapshot: start
  - keys: [down, down]
    snapshot: last
  - keys: [up]
    snapshot: middle
  - keys: [q]
    exit: true
    snapshot: after_quit
