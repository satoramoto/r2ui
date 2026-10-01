# F1 to F4 (SS3 sequences ESC O P..S) give key types -12..-15 named f1..f4.
require "bubbletea"

class Show
  include Bubbletea::Model

  FLAGS = %i[ctrl? runes? space? enter? backspace? tab? esc? up? down? left? right?].freeze

  def initialize
    @lines = []
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage)
      flags = FLAGS.select { |f| message.public_send(f) }.map { |f| f.to_s.chomp("?") }
      @lines << "#{message.to_s.inspect} type=#{message.key_type} runes=#{message.runes.inspect} " \
                "alt=#{message.alt} char=#{message.char.inspect} flags=#{flags.join(',')}"
    end
    [self, nil]
  end

  def view = (["keys:"] + @lines).join("\n")
end

Bubbletea.run(Show.new)

__END__
size: 80x10
steps:
  - input: "\eOP"
  - input: "\eOQ"
  - input: "\eOR"
  - input: "\eOS"
    snapshot: f1_f4
