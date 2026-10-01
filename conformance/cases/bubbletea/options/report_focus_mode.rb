# report_focus: true enables focus reporting while running and disables it on exit.
require "bubbletea"

class App
  include Bubbletea::Model

  def update(message)
    return [self, Bubbletea.quit] if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "q"

    [self, nil]
  end

  def view
    "report focus"
  end
end

Bubbletea.run(App.new, report_focus: true)

__END__
size: 30x5
steps:
  - snapshot: running
  - keys: [q]
    exit: true
    snapshot: after_quit
