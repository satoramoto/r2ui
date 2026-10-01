# Entering an empty subdirectory lists just the ".." entry.
require "bubbletea"
require "bubbles"
require "tmpdir"
require "fileutils"

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
  FileUtils.mkdir_p(File.join(root, "empty"))
  File.chmod(0o755, root)
  File.chmod(0o755, File.join(root, "empty"))
  Bubbletea.run(App.new(root))
end

__END__
size: 70x14
steps:
  - keys: [enter]
    snapshot: in_empty
  - keys: [q]
    exit: true
