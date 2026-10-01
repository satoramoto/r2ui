# Keys sent one at a time arrive in order, mixing letters, space, enter and backspace.
require "bubbletea"

class Show
  include Bubbletea::Model

  def initialize
    @text = +""
    @names = []
  end

  def init = [self, nil]

  def update(message)
    return [self, nil] unless message.is_a?(Bubbletea::KeyMessage)

    @names << message.to_s
    if message.runes? || message.space?
      @text << message.char
    elsif message.backspace?
      @text.chop!
    end
    [self, nil]
  end

  def view = "text: #{@text.inspect}\nnames: #{@names.join(' ')}"
end

Bubbletea.run(Show.new)

__END__
size: 80x6
steps:
  - keys: [h, i, space, t, x, backspace, h, e, r, e, enter]
    snapshot: typed
