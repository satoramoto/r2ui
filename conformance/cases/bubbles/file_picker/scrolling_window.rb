# With height 4 and 12 files the visible window scrolls to keep the cursor in view going down, and back up again.
require "bubbletea"
require "bubbles"
require "tmpdir"

class App
  include Bubbletea::Model

  def initialize(root)
    @root = root
    @picker = Bubbles::FilePicker.new(directory: root)
    @picker.height = 4
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

  def view = "#{@picker.view.gsub(@root, '<root>')}\ncursor=#{@picker.cursor}"
end

Dir.mktmpdir("r2ui-fp") do |dir|
  root = File.realpath(dir)
  (1..12).each { |i| File.write(File.join(root, format("file%02d.txt", i)), "x" * i) }
  Bubbletea.run(App.new(root))
end

__END__
size: 50x9
steps:
  - snapshot: start
  - keys: [j, j, j]
    snapshot: last_visible
  - keys: [j]
    snapshot: scrolled_one
  - keys: [j, j, j, j, j, j, j, j]
    snapshot: at_end
  - keys: [k, k, k, k, k]
    snapshot: scrolled_back
  - keys: [q]
    exit: true
