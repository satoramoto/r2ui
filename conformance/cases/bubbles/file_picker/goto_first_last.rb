# G and end jump to the last entry; g and home jump back to the first.
require "bubbletea"
require "bubbles"
require "tmpdir"
require "fileutils"

def build_fixture(root)
  { "alpha.txt" => 5, "beta.rb" => 1500, "Gamma.md" => 0, "docs/readme.md" => 12,
    "docs/notes.txt" => 2048, "docs/deep/leaf.txt" => 3, ".hidden" => 1 }.each do |name, size|
    path = File.join(root, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "x" * size)
    File.chmod(0o644, path)
  end
  FileUtils.mkdir_p(File.join(root, "src"))
  [root, File.join(root, "docs"), File.join(root, "docs", "deep"), File.join(root, "src")].each { |d| File.chmod(0o755, d) }
end

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

  def view
    path = @picker.path&.sub(@root, "<root>").inspect
    "#{@picker.view.gsub(@root, '<root>')}\ncursor=#{@picker.cursor} did=#{@picker.did_select_file?} path=#{path}"
  end
end

Dir.mktmpdir("r2ui-fp") do |dir|
  root = File.realpath(dir)
  build_fixture(root)
  Bubbletea.run(App.new(root))
end

__END__
size: 70x14
steps:
  - keys: [G]
    snapshot: last_G
  - keys: [g]
    snapshot: first_g
  - keys: [end]
    snapshot: last_end
  - keys: [home]
    snapshot: first_home
  - keys: [q]
    exit: true
