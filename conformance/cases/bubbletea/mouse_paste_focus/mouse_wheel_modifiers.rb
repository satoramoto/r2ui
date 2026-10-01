# Modifiers combine with the wheel: ctrl+wheel up (SGR 80) and shift+wheel down (SGR 69).
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
size: 100x8
steps:
  - input: "\e[<80;9;9M"
  - input: "\e[<69;9;9M"
    snapshot: wheel_mods
