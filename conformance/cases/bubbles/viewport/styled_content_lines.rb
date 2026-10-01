# ANSI-styled content lines keep their styling in the viewport and wide-line cutting measures visible width only.
require "bubbletea"
require "bubbles"
require "lipgloss"

class App
  include Bubbletea::Model

  def initialize
    @vp = Bubbles::Viewport.new(width: 12, height: 3)
    bold = Lipgloss::Style.new.bold(true)
    red = Lipgloss::Style.new.foreground("#ff0000")
    @vp.content = [bold.render("bold head"), red.render("red text"), "plain", bold.render("0123456789ABCDEF")].join("\n")
  end

  def init = [self, nil]

  def update(message)
    @vp, command = @vp.update(message)
    [self, command]
  end

  def view = @vp.view
end

Bubbletea.run(App.new)

__END__
size: 30x6
steps:
  - snapshot: start
  - keys: [j]
    snapshot: scrolled
