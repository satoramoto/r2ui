# Ticks batched together fire in order of their durations, not the order they were listed.
require "bubbletea"

class Fired < Bubbletea::Message
  attr_reader :name

  def initialize(name)
    super()
    @name = name
  end
end

class App
  include Bubbletea::Model

  def initialize
    @order = []
  end

  def init
    [self, Bubbletea.batch(
      Bubbletea.tick(0.4) { Fired.new("slow") },
      Bubbletea.tick(0.05) { Fired.new("fast") },
      Bubbletea.tick(0.2) { Fired.new("mid") }
    )]
  end

  def update(message)
    case message
    when Fired then @order << message.name
    when Bubbletea::KeyMessage then return [self, Bubbletea.quit] if message.to_s == "q"
    end
    [self, nil]
  end

  def view
    "order: #{@order.join(',')}"
  end
end

Bubbletea.run(App.new)

__END__
size: 40x5
steps:
  - wait_for: "order: fast,mid,slow"
    snapshot: ordered
  - keys: [q]
    exit: true
