# Binding exposes keys, help, help? and enabled?; help? needs both a key label and a description.
require "bubbletea"
require "bubbles"

class Host
  include Bubbletea::Model

  def initialize
    full = Bubbles::Key.binding(keys: "enter", help: ["⏎", "select"])
    half = Bubbles::Key.binding(keys: %w[a b], help: ["a", ""])
    none = Bubbles::Key.binding(keys: %w[c], enabled: false)
    @lines = [full, half, none].map do |b|
      "keys=#{b.keys.inspect} help=#{b.help.inspect} help?=#{b.help?} enabled?=#{b.enabled?}"
    end
  end

  def init = [self, nil]

  def update(message) = [self, nil]

  def view = @lines.join("\n")
end

Bubbletea.run(Host.new)

__END__
size: 90x5
steps:
  - snapshot: api
