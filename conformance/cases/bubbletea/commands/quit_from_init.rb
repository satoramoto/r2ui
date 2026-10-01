# init returning Bubbletea.quit exits immediately, before any view is drawn.
require "bubbletea"

class App
  include Bubbletea::Model

  def init
    [self, Bubbletea.quit]
  end

  def view
    "never drawn"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - exit: true
    snapshot: exited
