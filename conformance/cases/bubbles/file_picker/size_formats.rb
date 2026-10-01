# File sizes render as bytes, K and M with one decimal under 100 and none from 100 up; permissions render from the mode bits.
require "bubbletea"
require "bubbles"
require "tmpdir"
require "fileutils"

SIZES = { "f0" => [0, 0o644], "f1" => [1, 0o600], "f1023" => [1023, 0o755], "f1024" => [1024, 0o444],
          "f1536" => [1536, 0o640], "f102400" => [102_400, 0o664], "f150000" => [150_000, 0o666],
          "f1m" => [1_048_576, 0o700], "f2500k" => [2_560_000, 0o751] }.freeze

def build_fixture(root)
  SIZES.each do |name, (size, mode)|
    path = File.join(root, name)
    File.write(path, "x" * size)
    File.chmod(mode, path)
  end
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

  def view = @picker.view.gsub(@root, "<root>")
end

Dir.mktmpdir("r2ui-fp") do |dir|
  root = File.realpath(dir)
  build_fixture(root)
  Bubbletea.run(App.new(root))
end

__END__
size: 70x14
steps:
  - snapshot: start
  - keys: [q]
    exit: true
