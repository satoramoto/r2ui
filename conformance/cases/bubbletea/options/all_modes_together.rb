# alt_screen, mouse_cell_motion, bracketed_paste and report_focus together: all on while running, all restored on exit.
require "bubbletea"

class App
  include Bubbletea::Model

  def update(message)
    return [self, Bubbletea.quit] if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "q"

    [self, nil]
  end

  def view
    "everything on"
  end
end

Bubbletea.run(App.new, alt_screen: true, mouse_cell_motion: true, bracketed_paste: true, report_focus: true)

__END__
size: 30x5
steps:
  - snapshot: running
  - keys: [q]
    exit: true
    snapshot: after_quit
