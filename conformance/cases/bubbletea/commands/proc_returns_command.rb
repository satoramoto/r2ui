# A lambda command may return another command (here quit) instead of a message; it is executed.
require "bubbletea"

class App
  include Bubbletea::Model

  def init
    [self, -> { Bubbletea.quit }]
  end

  def view
    "waiting to quit"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - exit: true
    snapshot: exited
