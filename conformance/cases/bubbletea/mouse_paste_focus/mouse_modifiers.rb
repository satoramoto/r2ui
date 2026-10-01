# Modifier bits on a left click: shift (4), alt (8), ctrl (16), and all three together (28).
require "bubbletea"

class Show
  include Bubbletea::Model

  FLAGS = %i[press? release? motion? wheel? left? right? middle?].freeze

  def initialize
    @lines = []
  end

  def init = [self, nil]

  def update(message)
    case message
    when Bubbletea::MouseMessage
      flags = FLAGS.select { |f| message.public_send(f) }.map { |f| f.to_s.chomp("?") }
      @lines << "mouse #{message.x},#{message.y} button=#{message.button} action=#{message.action} " \
                "shift=#{message.shift} alt=#{message.alt} ctrl=#{message.ctrl} #{flags.join(',')}"
    when Bubbletea::KeyMessage
      return [self, Bubbletea.quit] if message.to_s == "q"

      @lines << "key #{message.to_s.inspect}"
    when Bubbletea::FocusMessage then @lines << "focus"
    when Bubbletea::BlurMessage then @lines << "blur"
    end
    [self, nil]
  end

  def view = (["events:"] + @lines).join("\n")
end

Bubbletea.run(Show.new, mouse_cell_motion: true)

__END__
size: 100x10
steps:
  - input: "\e[<4;2;2M"
  - input: "\e[<8;2;2M"
  - input: "\e[<16;2;2M"
  - input: "\e[<28;2;2M"
    snapshot: modifiers
