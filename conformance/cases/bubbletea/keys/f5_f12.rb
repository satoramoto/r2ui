# F5 to F12 (CSI 15~..24~, skipping 16 and 22) give key types -16..-23 named f5..f12.
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
size: 80x14
steps:
  - input: "\e[15~"
  - input: "\e[17~"
  - input: "\e[18~"
  - input: "\e[19~"
  - input: "\e[20~"
  - input: "\e[21~"
  - input: "\e[23~"
  - input: "\e[24~"
    snapshot: f5_f12
