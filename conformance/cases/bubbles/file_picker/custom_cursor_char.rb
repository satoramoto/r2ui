# A custom cursor_char replaces the ">" marker on the selected row.
require "bubbletea"
require "bubbles"
require "tmpdir"

class App
  include Bubbletea::Model

  def initialize(root)
    @root = root
    @picker = Bubbles::FilePicker.new(directory: root)
    @picker.cursor_char = "→"
    @picker.show_permissions = false
  end

  def init = [self, nil]

  def update(message)
    if message.is_a?(Bubbletea::KeyMessage)
      return [self, Bubbletea.quit] if message.to_s == "q"

      @picker, command = @picker.update(message)
      return [self, command]
    end
    [self, nil]
  end

  def view = @picker.view.gsub(@root, "<root>")
end

Dir.mktmpdir("r2ui-fp") do |dir|
  root = File.realpath(dir)
  %w[one.txt two.txt three.txt].each { |n| File.write(File.join(root, n), "abc") }
  Bubbletea.run(App.new(root))
end

__END__
size: 50x14
steps:
  - snapshot: start
  - keys: [j]
    snapshot: moved
  - keys: [q]
    exit: true
