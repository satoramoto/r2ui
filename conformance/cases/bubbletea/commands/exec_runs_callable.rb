# exec hands the terminal to a callable, then delivers the given message when it returns.
require "bubbletea"

class Done < Bubbletea::Message; end

class App
  include Bubbletea::Model

  def initialize
    @state = "idle"
  end

  def update(message)
    case message
    when Done then @state = "returned"
    when Bubbletea::KeyMessage
      case message.to_s
      when "e"
        @state = "running"
        return [self, Bubbletea.exec(-> { $stdout.print("[callable ran]"); $stdout.flush }, message: Done.new)]
      when "q" then return [self, Bubbletea.quit]
      end
    end
    [self, nil]
  end

  def view
    "state: #{@state}"
  end
end

Bubbletea.run(App.new)

__END__
size: 40x6
steps:
  - snapshot: start
  - keys: [e]
    wait_for: "state: returned"
    snapshot: after_exec
  - keys: [q]
    exit: true
