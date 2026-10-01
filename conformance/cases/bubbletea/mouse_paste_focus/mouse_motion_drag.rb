# Drag: SGR 32 (button 0 + motion bit) reports action motion with button 0, between a press and a release.
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
  - input: "\e[<0;5;5M"
  - input: "\e[<32;6;5M"
  - input: "\e[<32;7;6M"
  - input: "\e[<0;7;6m"
    snapshot: drag
