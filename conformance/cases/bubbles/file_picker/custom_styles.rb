# Custom lipgloss styles for the path/dir, file, selected row, cursor, size and permissions replace the default ANSI colours.
require "bubbletea"
require "bubbles"
require "lipgloss"
require "tmpdir"
require "fileutils"

class App
  include Bubbletea::Model

  def initialize(root)
    @root = root
    @picker = Bubbles::FilePicker.new(directory: root)
    @picker.dir_style = Lipgloss::Style.new.foreground("#00aaff")
    @picker.file_style = Lipgloss::Style.new.foreground("#cccccc")
    @picker.selected_style = Lipgloss::Style.new.bold(true).foreground("#ffcc00")
    @picker.cursor_style = Lipgloss::Style.new.foreground("#ff0066")
    @picker.size_style = Lipgloss::Style.new.foreground("#777777")
    @picker.permission_style = Lipgloss::Style.new.italic(true)
    @picker.disabled_style = Lipgloss::Style.new.faint(true)
    @picker.allowed_types = ["txt"]
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
  FileUtils.mkdir_p(File.join(root, "sub"))
  File.chmod(0o755, File.join(root, "sub"))
  { "a.txt" => 10, "b.txt" => 2000, "c.bin" => 30 }.each do |name, size|
    File.write(File.join(root, name), "x" * size)
    File.chmod(0o644, File.join(root, name))
  end
  Bubbletea.run(App.new(root))
end

__END__
size: 70x14
steps:
  - snapshot: dir_selected
  - keys: [j]
    snapshot: file_selected
  - keys: [j, j]
    snapshot: disabled_file_selected
  - keys: [q]
    exit: true
