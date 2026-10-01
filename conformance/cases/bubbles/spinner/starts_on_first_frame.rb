# Before any tick the spinner shows its first frame (the model sends no tick command).
require "bubbletea"
require "bubbles"

class App
  include Bubbletea::Model

  def initialize
    @spinner = Bubbles::Spinner.new(spinner: Bubbles::Spinners::MINI_DOT)
  end

  def init = [self, nil]

  def update(_message) = [self, nil]

  def view = "[#{@spinner.view}] idle"
end

Bubbletea.run(App.new)

__END__
size: 30x3
steps:
  - snapshot: start
