# text_style, prompt_style, line_number_style and placeholder_style (end-of-buffer) are applied.
require "bubbletea"
require "lipgloss"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @area = Bubbles::TextArea.new(width: 20, height: 3)
    @area.show_line_numbers = true
    @area.prompt = "> "
    @area.text_style = Lipgloss::Style.new.foreground("#00AFFF")
    @area.prompt_style = Lipgloss::Style.new.foreground("#FF8700")
    @area.line_number_style = Lipgloss::Style.new.foreground("#888888")
    @area.placeholder_style = Lipgloss::Style.new.foreground("#5F5F5F")
    @area.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @area.focus
    @area.value = "ab\ncd"
  end

  def init = [self, nil]

  def update(message)
    @area, command = @area.update(message)
    [self, command]
  end

  def view = @area.view
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - snapshot: start
