# A command returned from update (send_message) is processed like one from init: a key causes a follow-up message.
require "bubbletea"

class Followup < Bubbletea::Message; end

class App
  include Bubbletea::Model

  def initialize
    @log = []
  end

  def update(message)
    case message
    when Followup then @log << "followup"
    when Bubbletea::KeyMessage
      case message.to_s
      when "f"
        @log << "key"
        return [self, Bubbletea.send_message(Followup.new)]
      when "q" then return [self, Bubbletea.quit]
      end
    end
    [self, nil]
  end

  def view
    "log: #{@log.join(',')}"
  end
end

Bubbletea.run(App.new)

__END__
size: 30x5
steps:
  - snapshot: start
  - keys: [f]
    wait_for: "log: key,followup"
    snapshot: after
  - keys: [q]
    exit: true
