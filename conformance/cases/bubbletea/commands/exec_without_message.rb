# exec with no message: the callable runs and the program carries on, still accepting keys.
require "bubbletea"

class App
  include Bubbletea::Model

  def initialize
    @keys = 0
  end

  def update(message)
    return [self, nil] unless message.is_a?(Bubbletea::KeyMessage)

    case message.to_s
    when "e" then [self, Bubbletea.exec(-> { $stdout.print("[ran]"); $stdout.flush })]
    when "q" then [self, Bubbletea.quit]
    else
      @keys += 1
      [self, nil]
    end
  end

  def view
    "other keys: #{@keys}"
  end
end

Bubbletea.run(App.new)

__END__
size: 40x6
steps:
  - snapshot: start
  - keys: [e]
    snapshot: after_exec
  - keys: [x]
    snapshot: still_alive
  - keys: [q]
    exit: true
