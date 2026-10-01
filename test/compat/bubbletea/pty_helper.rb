# frozen_string_literal: true

require "pty"
require "io/console"
require "rbconfig"

# Runs a Ruby program on a fresh pty (no real terminal needed) and records every byte it writes.
# Used to drive our Bubbletea and, for comparison, the real gem in a separate process.
module PtyHelper
  LIB = File.expand_path("../../../lib", __dir__)
  SHIM = File.expand_path("fixtures/load_path", __dir__)

  Run = Struct.new(:output, :status, :tty_restored, keyword_init: true)

  # Prelude that loads OUR bubbletea through r2ui/drop_in and fails if the real gem got loaded.
  OURS = <<~RUBY
    require "r2ui/drop_in"
    require "bubbletea"
    at_exit { abort "real bubbletea loaded" if $LOADED_FEATURES.grep(%r{/gems/bubbletea-}).any? }
  RUBY

  # Prelude for OUR bubbletea next to the REAL lipgloss (for bubbles while the style lane is pending).
  OURS_WITH_REAL_LIPGLOSS = <<~RUBY
    require "bubbletea"
    abort "shim not used" unless defined?(R2UI::Compat::Tea)
    at_exit { abort "real bubbletea loaded" if $LOADED_FEATURES.grep(%r{/gems/bubbletea-}).any? }
  RUBY

  REAL = <<~RUBY
    require "bubbletea"
  RUBY

  module_function

  # Asked of a subprocess outside bundler: under `bundle exec` gems outside the bundle are hidden.
  def real_gem?(name = "bubbletea", version = "0.1.4")
    @real_gem ||= {}
    @real_gem.fetch([name, version]) do
      @real_gem[[name, version]] = unbundled do
        system(RbConfig.ruby, "-e", "gem #{name.dump}, #{version.dump}", out: File::NULL, err: File::NULL)
      end
    end
  end

  def unbundled(&)
    defined?(Bundler) ? Bundler.with_unbundled_env(&) : yield
  end

  # Spawns `ruby -e code` on a pty of the given size. `script` receives a driver with
  # `wait_for(text)`, `type(bytes)`, `pause(seconds)`, `signal(name)`. Returns a Run.
  def run(code, load_path: [], width: 60, height: 20, timeout: 15)
    master, slave = PTY.open
    slave.winsize = [height, width]
    output = +"".b
    reader = Thread.new do
      loop { output << master.readpartial(4096) }
    rescue EOFError, Errno::EIO, IOError
      nil
    end
    args = load_path.flat_map { |dir| ["-I", dir] }
    pid = unbundled { Process.spawn(RbConfig.ruby, *args, "-e", code, in: slave, out: slave, err: slave) }
    driver = Driver.new(pid, master, output)
    yield driver if block_given?
    status = wait(pid, timeout)
    sleep 0.05 # let the reader drain what the child wrote last
    Run.new(output: output.dup, status: status, tty_restored: slave.echo?)
  ensure
    if pid && !status
      Process.kill("KILL", pid) rescue nil # rubocop:disable Style/RescueModifier
      Process.wait(pid) rescue nil # rubocop:disable Style/RescueModifier
    end
    slave&.close
    master&.close
    reader&.join(1)
    reader&.kill
  end

  def wait(pid, timeout)
    deadline = Time.now + timeout
    loop do
      _, status = Process.wait2(pid, Process::WNOHANG)
      return status if status
      raise "program did not exit within #{timeout}s" if Time.now > deadline

      sleep 0.01
    end
  end

  class Driver
    def initialize(pid, master, output)
      @pid = pid
      @master = master
      @output = output
    end

    def wait_for(text, timeout: 10)
      deadline = Time.now + timeout
      sleep 0.01 until @output.include?(text.b) || Time.now > deadline
      raise "timed out waiting for #{text.inspect}; got #{@output.inspect}" unless @output.include?(text.b)
    end

    def type(*keys, gap: 0.08)
      keys.each do |key|
        @master.write(key)
        @master.flush
        sleep gap
      end
    end

    def pause(seconds) = sleep(seconds)

    def signal(name) = Process.kill(name, @pid)
  end
end
