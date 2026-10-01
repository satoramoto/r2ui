# A quit inside a batch ends the program.
require "bubbletea"

class App
  include Bubbletea::Model

  def init
    [self, Bubbletea.batch(Bubbletea.send_message(:unused), Bubbletea.quit)]
  end

  def update(_message)
    [self, nil]
  end

  def view
    "running"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - exit: true
    snapshot: exited
