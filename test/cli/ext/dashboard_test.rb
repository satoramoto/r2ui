# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require "tmpdir"
require "open3"
require "rbconfig"
require "pty"
require "io/console"

# c25-dashboard: `run { dashboard :fleet, file: "dashboards.rb" }`.
module DashboardTestFile
  SOURCE = <<~RUBY
    R2UI.resource :ship do
      source { [{ name: "alpha", status: "up" }, { name: "beta", status: "down" }] }
      index do
        column :name
        column :status
      end
    end

    R2UI.dashboard :fleet do
      title "Fleet"
      row { panel :ship }
    end
  RUBY

  def setup
    @dir = Dir.mktmpdir("c25")
    @file = File.join(@dir, "dashboards.rb")
    File.write(@file, SOURCE)
  end

  def teardown
    FileUtils.remove_entry(@dir)
    R2UI.reset! if defined?(R2UI.reset!)
  end

  def program(name = :fleet, **options)
    file = options.key?(:file) ? options.delete(:file) : @file
    R2UI::CLI::Program.build("tool") do
      run { dashboard(name, file:, **options) }
    end
  end

  # What `r2ui --snapshot --width W --height H dashboards.rb fleet` prints: the frame, puts'd
  # (its last row is the status line, empty in plain text).
  def expected_frame(width:, height:)
    require "r2ui"
    R2UI.reset!
    load @file
    frame = R2UI.snapshot(:fleet, width:, height:)
    frame.end_with?("\n") ? frame : "#{frame}\n"
  ensure
    R2UI.reset!
  end
end

# Off an interactive shell (a pipe, CI): one plain frame at the shell's width.
class DashboardPipeTest < Minitest::Test
  include R2UI::CLI::Testing
  include DashboardTestFile

  def test_prints_one_snapshot_frame_at_the_shell_width
    result = run_cli(program, width: 60)
    assert_equal 0, result.code, result.err
    assert_equal expected_frame(width: 60, height: 24), result.out
    assert_equal "", result.err
  end

  def test_frame_shows_the_dashboard
    out = run_cli(program, width: 60).out
    assert_includes out, "Ship"
    assert_includes out, "alpha"
    assert_includes out, "beta"
    refute_includes out, "\e"
  end

  def test_frame_fits_the_width
    lines = run_cli(program, width: 40).out.lines(chomp: true)
    assert_equal expected_frame(width: 40, height: 24).lines(chomp: true), lines
    assert(lines.all? { |line| line.length <= 40 }, lines.inspect)
    refute_equal lines, run_cli(program, width: 70).out.lines(chomp: true)
  end

  def test_height_follows_the_shell
    result = run_cli(program, width: 60, env: { "LINES" => "12" })
    assert_equal expected_frame(width: 60, height: 12), result.out
  end

  def test_height_can_be_given
    assert_equal expected_frame(width: 60, height: 10), run_cli(program(height: 10), width: 60).out
  end

  def test_terminal_without_interactive_input_prints_the_frame
    result = run_cli(program, width: 60, tty: true, interactive: false)
    assert_equal 0, result.code
    assert_equal expected_frame(width: 60, height: 24), result.out
  end

  def test_relative_file_resolves_from_the_working_directory
    Dir.chdir(@dir) do
      assert_includes run_cli(program(file: "dashboards.rb"), width: 60).out, "alpha"
    end
  end

  # A tool at <dir>/tool.rb with `file: "dashboards.rb"` finds <dir>/dashboards.rb from any cwd.
  def test_relative_file_resolves_next_to_the_calling_file
    tool = File.join(@dir, "tool.rb")
    File.write(tool, <<~RUBY)
      $c25_tool = R2UI::CLI::Program.build("tool") { run { dashboard :fleet, file: "dashboards.rb" } }
    RUBY
    load tool
    program = $c25_tool # rubocop:disable Style/GlobalVars
    Dir.chdir(Dir.tmpdir) do
      assert_includes run_cli(program, width: 60).out, "alpha"
    end
  end

  def test_without_a_file_uses_dashboards_already_defined
    load_dsl
    load @file
    assert_includes run_cli(program(file: nil), width: 60).out, "alpha"
  end

  def test_missing_file_exits_1
    result = run_cli(program(file: File.join(@dir, "nope.rb")))
    assert_equal 1, result.code
    assert_equal "", result.out
    assert_includes result.err, "✖ no dashboard file"
    assert_includes result.err, "nope.rb"
  end

  def test_unknown_dashboard_exits_1
    result = run_cli(program(:armada))
    assert_equal 1, result.code
    assert_includes result.err, "✖"
    assert_includes result.err, "armada"
  end

  def test_running_twice_does_not_duplicate
    first = run_cli(program, width: 60).out
    assert_equal first, run_cli(program, width: 60).out
  end

  def test_helper_works_in_a_script
    value, shell = with_shell(width: 50) { R2UI::CLI.dashboard(:fleet, file: @file) }
    assert_nil value
    assert_includes shell.output.string, "alpha"
  end

  # `require "r2ui/cli"` stays fast: the dashboard DSL loads only when a command opens one.
  def test_dashboard_dsl_loads_only_when_used
    script = <<~RUBY
      require "r2ui/cli"
      require "stringio"
      print defined?(R2UI::App) ? "loaded" : "not loaded"
      print " "
      R2UI::CLI.shell = R2UI::CLI::Shell.new(output: StringIO.new, env: {})
      R2UI::CLI.dashboard(:fleet, file: #{@file.inspect})
      print defined?(R2UI::App) ? "loaded" : "not loaded"
    RUBY
    out, err, status = Open3.capture3(RbConfig.ruby, "-I", File.expand_path("../../../lib", __dir__), "-e", script)
    assert status.success?, err
    assert_equal "not loaded loaded", out
  end

  private

  def load_dsl = require("r2ui")
end

# On a terminal: the dashboard runs full screen until the user quits, then the terminal is back.
class DashboardTerminalTest < Minitest::Test
  include DashboardTestFile

  def setup
    super
    @master, @slave = PTY.open
    @slave.winsize = [20, 70]
    @buffer = +""
    @lock = Mutex.new
    @reader = Thread.new do
      loop do
        chunk = @master.readpartial(4096)
        @lock.synchronize { @buffer << chunk.force_encoding(Encoding::UTF_8) }
      end
    rescue IOError, Errno::EIO
      nil
    end
    @shell = R2UI::CLI::Shell.new(input: @slave, output: @slave, error: @slave, env: { "TERM" => "xterm" })
  end

  def teardown
    if @runner
      @runner.kill
      begin
        @runner.join(1)
      rescue Exception # rubocop:disable Lint/RescueException -- join re-raises the thread's error
        nil
      end
    end
    @slave.close unless @slave.closed?
    @master.close unless @master.closed?
    @reader&.kill
    @reader&.join(1)
    super
  end

  def open_dashboard
    program = program()
    shell = @shell
    @runner = Thread.new { program.call([], shell:) }
    @runner.report_on_exception = false
    @runner
  end

  def output = @lock.synchronize { @buffer.dup }

  def plain = output.gsub(/\e\[[0-9;?]*[A-Za-z]/, "")

  def wait_for(text, timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until output.include?(text) || plain.include?(text)
      flunk "timed out waiting for #{text.inspect}; output: #{plain.inspect}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      Thread.pass
      sleep 0.01
    end
  end

  def test_shell_is_interactive
    assert @shell.interactive?
  end

  def test_runs_full_screen_and_returns_when_the_user_quits
    runner = open_dashboard
    wait_for("\e[?1049h")
    wait_for("alpha")
    refute @slave.echo?, "dashboard should run in raw mode"
    @master.write("q")
    assert runner.join(5), "dashboard did not return after q"
    assert_equal 0, runner.value
    wait_for("\e[?1049l")
    assert @slave.echo?, "terminal left in raw mode"
    after_exit = output.split("\e[?1049l").last
    assert_includes after_exit, "\e[?25h", "cursor left hidden"
  end

  def test_ctrl_c_quits_and_restores_the_terminal
    runner = open_dashboard
    wait_for("alpha")
    @master.write("\x03")
    assert runner.join(5), "dashboard did not return after ctrl+c"
    wait_for("\e[?1049l")
    assert @slave.echo?, "terminal left in raw mode"
  end

  def test_does_not_print_a_snapshot_on_a_terminal
    runner = open_dashboard
    wait_for("alpha")
    @master.write("q")
    runner.join(5)
    before_alt = output.split("\e[?1049h").first.to_s
    refute_includes before_alt, "alpha"
  end
end
