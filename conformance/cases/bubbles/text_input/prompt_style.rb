# prompt_style, text_style and placeholder_style are applied to the prompt, typed text and placeholder.
require "bubbletea"
require "lipgloss"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.placeholder = "type here"
    @input.prompt_style = Lipgloss::Style.new.foreground("#FF8700").bold(true)
    @input.text_style = Lipgloss::Style.new.foreground("#00AFFF")
    @input.placeholder_style = Lipgloss::Style.new.foreground("#5F5F5F")
    @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
    @input.focus
  end

  def init = [self, nil]

  def update(message)
    @input, command = @input.update(message)
    [self, command]
  end

  def view = @input.view
end

Bubbletea.run(App.new)

__END__
size: 40x3
steps:
  - snapshot: placeholder
  - keys: [a, b, c, left]
    snapshot: typed
