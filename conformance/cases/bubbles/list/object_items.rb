# Objects with #title are rendered by title; #filter_value (when present) is what the filter matches.
require "bubbletea"
require "bubbles"

Entry = Struct.new(:title, :filter_value)

class Host
  include Bubbletea::Model

  def initialize
    items = [Entry.new("Alpha", "first greek"), Entry.new("Beta", "second greek"), Entry.new("Gamma", "third letter")]
    @c = Bubbles::List.new(items, width: 30, height: 8)
  end

  def init = [self, nil]

  def update(message)
    @c, command = @c.update(message)
    [self, command]
  end

  def view = @c.view
end

Bubbletea.run(Host.new)

__END__
size: 30x10
steps:
  - snapshot: start
  - keys: ["/", g, r, e, e, k]
    snapshot: filter_by_value
  - keys: [enter]
    snapshot: applied
