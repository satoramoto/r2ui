# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require "pty"
require "io/console"
require "tmpdir"
require "fileutils"

TALL = (1..30).map { |i| "line #{i}" }.join("\n") + "\n"

# Off an interactive terminal (pipe, CI): the text is printed, no pager runs.
class PagerPipeTest < Minitest::Test
  include R2UI::CLI::Testing

  def test_prints_the_text_in_a_pipe
    _, shell = with_shell { R2UI::CLI.pager(TALL) }
    assert_equal TALL, shell.output.string
    assert_equal "", shell.error.string
  end

  def test_adds_a_final_newline
    _, shell = with_shell { R2UI::CLI.pager("one\ntwo") }
    assert_equal "one\ntwo\n", shell.output.string
  end

  def test_returns_nil
    value, = with_shell { R2UI::CLI.pager("hi") }
    assert_nil value
  end

  def test_never_runs_the_pager_off_a_terminal
    Dir.mktmpdir do |dir|
      marker = File.join(dir, "ran")
      _, shell = with_shell(tty: true, env: { "PAGER" => "touch #{marker}" }) { R2UI::CLI.pager(TALL) }
      refute File.exist?(marker), "pager ran without an interactive shell"
      assert_equal TALL, shell.output.string
    end
  end

  def test_empty_text_prints_nothing
    _, shell = with_shell { R2UI::CLI.pager("") }
    assert_equal "", shell.output.string
  end

  def test_inside_a_live_region_prints_above_it
    _, shell = with_shell(tty: true, interactive: true, env: { "PAGER" => "r2ui-no-such-pager" }) do
      R2UI::CLI.tasks { R2UI::CLI.step("Building") { R2UI::CLI.pager(TALL) } }
    end
    plain = shell.output.string.gsub(/\e\[[0-9;?]*[A-Za-z]/, "")
    assert_includes plain, "line 1\n"
    assert_includes plain, "line 30\n"
    refute_includes plain, "line 30\n\n"
  end

  def test_pages_from_a_command
    program = R2UI::CLI::Program.build("tool") { run { pager(TALL) } }
    result = run_cli(program)
    assert_equal 0, result.code
    assert_equal TALL, result.out
  end
end

# On a real pseudo-terminal, in this process.
class PagerTerminalTest < Minitest::Test
  def setup
    @master, @slave = PTY.open
    @slave.winsize = [10, 40]
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
    @dir = Dir.mktmpdir
  end

  def teardown
    @slave.close unless @slave.closed?
    @master.close unless @master.closed?
    @reader&.kill
    @reader&.join(1)
    FileUtils.remove_entry(@dir)
  end

  def shell(env = {})
    R2UI::CLI::Shell.new(input: @slave, output: @slave, error: @slave, env: { "TERM" => "xterm" }.merge(env))
  end

  def page(text, env = {})
    sh = shell(env)
    previous = R2UI::CLI.instance_variable_get(:@shell)
    R2UI::CLI.shell = sh
    R2UI::CLI.pager(text)
  ensure
    R2UI::CLI.shell = previous
  end

  def path(name) = File.join(@dir, name)

  # A pager that records its stdin (and arguments) and writes nothing.
  def recorder(name = "pager")
    script = path(name)
    File.write(script, "#!/bin/sh\necho \"$@\" > \"#{path("args")}\"\ncat > \"#{path("seen")}\"\n")
    File.chmod(0o755, script)
    script
  end

  def output = @lock.synchronize { @buffer.dup }

  def wait_for(text, timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until output.include?(text)
      flunk "timed out waiting for #{text.inspect}; output: #{output.inspect}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.01
    end
  end

  def test_taller_text_goes_through_the_pager_and_waits_for_it
    assert_nil page(TALL, "PAGER" => recorder)
    # The pager had finished when pager returned: its whole input is on disk.
    assert_equal TALL, File.read(path("seen"))
    sleep 0.1
    refute_includes output, "line 30", "text was printed as well as paged"
  end

  def test_text_that_fits_is_printed
    page("one\ntwo\n", "PAGER" => recorder)
    refute File.exist?(path("seen")), "pager ran for text that fits"
    wait_for("two")
  end

  def test_exactly_the_screen_height_is_printed
    text = (1..10).map { |i| "row #{i}" }.join("\n")
    page(text, "PAGER" => recorder)
    refute File.exist?(path("seen"))
    wait_for("row 10")
  end

  def test_wrapped_lines_count_toward_the_height
    text = (["x" * 100] * 4).join("\n") # 4 lines, 12 rows at 40 columns
    page(text, "PAGER" => recorder)
    assert_equal "#{text}\n", File.read(path("seen"))
  end

  def test_default_pager_is_less_with_raw_control_chars_quit_if_one_screen_no_init
    recorder("less")
    page(TALL, "PATH" => "#{@dir}:/usr/bin:/bin")
    assert_equal "-R -F -X\n", File.read(path("args"))
    assert_equal TALL, File.read(path("seen"))
  end

  def test_pager_arguments_are_split_like_a_shell
    page(TALL, "PAGER" => "#{recorder} -a 'two words'")
    assert_equal "-a two words\n", File.read(path("args"))
  end

  def test_empty_or_cat_pager_prints
    ["", "cat"].each do |value|
      page("#{TALL}#{value}-end\n", "PAGER" => value)
      wait_for("#{value}-end")
    end
  end

  def test_missing_pager_program_falls_back_to_printing
    page(TALL, "PAGER" => "r2ui-no-such-pager --flag")
    wait_for("line 30")
  end

  def test_pager_that_quits_early_is_fine
    big = (1..20_000).map { |i| "line #{i}" }.join("\n")
    assert_nil page(big, "PAGER" => "head -n 1")
    wait_for("line 1")
  end

  def test_restores_nothing_it_did_not_change
    before = trap("INT") { nil }
    trap("INT", before)
    page(TALL, "PAGER" => recorder)
    after = trap("INT", before)
    assert_equal before, after, "SIGINT handler changed"
    assert @slave.echo?, "terminal echo changed"
  end
end
