# An empty directory shows "No files found" under the path line.
require "bubbletea"
require "bubbles"
require "tmpdir"

class App
  include Bubbletea::Model

  def initialize(root)
    @root = root
    @picker = Bubbles::FilePicker.new(directory: root)
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
  Bubbletea.run(App.new(root))
end

__END__
size: 70x14
steps:
  - snapshot: start
  - keys: [j, enter, G]
    snapshot: keys_on_empty
  - keys: [q]
    exit: true
