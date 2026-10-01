# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require "pty"
require "io/console"

ASK_TOO_SHORT = ->(v) { "too short" if v.size < 2 }

# From a pipe (`echo app | tool`, CI): read a line silently, record the answer on stderr.
class AskPipeTest < Minitest::Test
  include R2UI::CLI::Testing

  def ask(input, **options)
    with_shell(input:) { R2UI::CLI.ask("Project name?", **options) }
  end

  def test_reads_a_line
    value, shell = ask("my-app\n")
    assert_equal "my-app", value
    assert_equal "✔ Project name? · my-app\n", shell.error.string
    assert_equal "", shell.output.string
  end

  def test_strips_surrounding_spaces
    assert_equal "my app", ask("  my app  \n").first
  end

  def test_empty_line_takes_the_default
    value, shell = ask("\n", default: "app")
    assert_equal "app", value
    assert_equal "✔ Project name? · app\n", shell.error.string
  end

  def test_end_of_input_takes_the_default
    assert_equal "app", ask("", default: "app").first
  end

  def test_empty_line_without_a_default_is_empty
    assert_equal "", ask("\n").first
  end

  def test_does_not_ask_from_a_pipe
    _, shell = ask("x\n", default: "app")
    refute_includes shell.error.string, "(app)"
  end

  def test_valid_answer_passes_validation
    assert_equal "ok", ask("ok\n", validate: ASK_TOO_SHORT).first
  end

  def test_the_default_is_validated_too
    error = assert_raises(R2UI::CLI::Error) { ask("\n", default: "a", validate: ASK_TOO_SHORT) }
    assert_includes error.message, "too short"
  end

  def test_end_of_input_without_a_default_exits_1_naming_the_question
    program = R2UI::CLI::Program.build("tool") do
      run { say(ask("Project name?")) }
    end
    result = run_cli(program, input: "")
    assert_equal 1, result.code
    assert_equal "", result.out
    assert_includes result.err, "Project name?"
    assert_includes result.err, "option"
  end

  def test_validation_failure_from_a_pipe_exits_1
    program = R2UI::CLI::Program.build("tool") do
      run { say(ask("Project name?", validate: ASK_TOO_SHORT)) }
    end
    result = run_cli(program, input: "a\n")
    assert_equal 1, result.code
    assert_equal "", result.out
    assert_includes result.err, "✖"
    assert_includes result.err, "Project name?"
    assert_includes result.err, "too short"
  end

  def test_answer_reaches_the_command
    program = R2UI::CLI::Program.build("tool") do
      run { say("created #{ask("Project name?", default: "app")}") }
    end
    assert_equal "created web\n", run_cli(program, input: "web\n").out
    assert_equal "created app\n", run_cli(program, input: "\n").out
  end

  def test_no_escape_codes_off_a_terminal
    _, shell = ask("web\n", default: "app", placeholder: "my-app", validate: ASK_TOO_SHORT)
    refute_includes shell.error.string, "\e"
  end
end

# stdin is a terminal, stdout piped (`tool | tee log`): ask a line on stderr, re-ask a person.
class AskTypedLineTest < Minitest::Test
  class FakeTerminal
    def initialize(*lines) = @lines = lines

    def tty? = true

    def gets = @lines.shift
  end

  def test_asks_on_stderr
    value, shell = ask_untyped("web\n")
    assert_equal "web", value
    assert_equal "Project name? ", shell.error.string
    assert_equal "", shell.output.string
  end

  def test_hint_shows_the_default
    value, shell = ask_untyped("\n", default: "app")
    assert_equal "app", value
    assert_equal "Project name? (app) ", shell.error.string
  end

  def test_asks_again_after_a_validation_failure
    value, shell = ask_untyped("a\n", "ab\n", validate: ASK_TOO_SHORT)
    assert_equal "ab", value
    assert_equal "Project name? ✖ too short\nProject name? ", shell.error.string
  end

  def test_end_of_input_takes_the_default
    assert_equal "app", ask_untyped(default: "app").first
  end

  def test_end_of_input_without_a_default_raises
    error = assert_raises(R2UI::CLI::Error) { ask_untyped }
    assert_includes error.message, "Project name?"
  end

  private

  def ask_untyped(*lines, **options)
    shell = R2UI::CLI::Shell.new(input: FakeTerminal.new(*lines), output: StringIO.new, error: StringIO.new, env: {})
    previous = R2UI::CLI.instance_variable_get(:@shell)
    R2UI::CLI.shell = shell
    [R2UI::CLI.ask("Project name?", **options), shell]
  ensure
    R2UI::CLI.shell = previous
  end
end

class AskModelTest < Minitest::Test
  include R2UI::CLI::Testing
  K = Bubbletea::KeyMessage

  def setup = R2UI::CLI.require_bubbles!

  def model(default: nil, placeholder: nil, validate: nil)
    m = R2UI::CLI::Ext::Ask::Model.new(test_shell, "Project name?", default:, placeholder:, validate:)
    m.init
    m
  end

  def rune(char) = K.new(key_type: K::KEY_RUNES, runes: [char.ord])

  def key(type) = K.new(key_type: type)

  def type(model, text)
    text.each_char { |c| model, = model.update(rune(c)) }
    model
  end

  def plain(text) = text.gsub(/\e\[[0-9;?]*[A-Za-z]/, "")

  def test_typing_then_enter_submits
    m = type(model, "my-app")
    m, command = m.update(key(K::KEY_ENTER))
    assert m.done?
    assert_equal "my-app", m.value
    refute_nil command
  end

  def test_enter_on_empty_takes_the_default
    m, = model(default: "app").update(key(K::KEY_ENTER))
    assert_equal "app", m.value
  end

  def test_view_while_asking_shows_the_question_and_text
    view = plain(type(model, "web").view)
    assert_includes view, "? Project name?"
    assert_includes view, "web"
  end

  def test_default_shows_as_the_placeholder
    assert_includes plain(model(default: "app").view), "app"
    assert_includes plain(model(default: "app", placeholder: "my-app").view), "my-app"
  end

  def test_validation_message_shows_under_until_fixed
    m = type(model(validate: ASK_TOO_SHORT), "a")
    m, command = m.update(key(K::KEY_ENTER))
    refute m.done?
    assert_nil command
    lines = plain(m.view).split("\n")
    assert_equal 2, lines.size
    assert_includes lines.last, "too short"
    m = type(m, "b")
    refute_includes plain(m.view), "too short"
    m, = m.update(key(K::KEY_ENTER))
    assert_equal "ab", m.value
  end

  def test_view_after_answering
    m, = type(model, "my-app").update(key(K::KEY_ENTER))
    assert_equal "✔ Project name? · my-app", m.view
  end

  def test_view_after_interrupt
    m, = model.update(key(K::KEY_CTRL_C))
    assert m.interrupted?
    assert_equal "✖ Project name?", m.view
  end
end

# The inline prompt on a real pseudo-terminal, in this process.
class AskTerminalTest < Minitest::Test
  def setup
    @master, @slave = PTY.open
    @slave.winsize = [10, 60]
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
    if @asker
      @asker.kill
      begin
        @asker.join(1)
      rescue Exception # rubocop:disable Lint/RescueException -- join re-raises the thread's Interrupt
        nil
      end
    end
    @slave.close unless @slave.closed?
    @master.close unless @master.closed?
    @reader&.kill
    @reader&.join(1)
  end

  def ask(question, **options)
    @asker = Thread.new do
      previous = R2UI::CLI.instance_variable_get(:@shell)
      R2UI::CLI.shell = @shell
      R2UI::CLI.ask(question, **options)
    ensure
      R2UI::CLI.shell = previous
    end
    @asker.report_on_exception = false
    @asker
  end

  def output = @lock.synchronize { @buffer.dup }

  def plain = output.gsub(/\e\[[0-9;?]*[A-Za-z]/, "")

  def wait_for(text, timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until plain.include?(text)
      flunk "timed out waiting for #{text.inspect}; output: #{plain.inspect}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      Thread.pass
      sleep 0.01
    end
  end

  def test_types_and_submits
    asker = ask("Project name?", default: "app")
    wait_for("Project name?")
    @master.write("web")
    wait_for("web")
    @master.write("\r")
    assert asker.join(5), "ask did not return"
    assert_equal "web", asker.value
    wait_for("✔ Project name? · web")
    assert @slave.echo?, "terminal left in raw mode"
  end

  def test_enter_takes_the_default
    asker = ask("Project name?", default: "app")
    wait_for("Project name?")
    @master.write("\r")
    assert asker.join(5), "ask did not return"
    assert_equal "app", asker.value
    wait_for("✔ Project name? · app")
  end

  def test_validation_message_until_fixed
    asker = ask("Project name?", validate: ASK_TOO_SHORT)
    wait_for("Project name?")
    @master.write("a\r")
    wait_for("too short")
    @master.write("b\r")
    assert asker.join(5), "ask did not return"
    assert_equal "ab", asker.value
    wait_for("✔ Project name? · ab")
  end

  def test_ctrl_c_raises_interrupt_and_restores_the_terminal
    asker = ask("Project name?")
    wait_for("Project name?")
    @master.write("\x03")
    assert_raises(Interrupt) { asker.join(5) }
    wait_for("✖ Project name?")
    assert @slave.echo?, "terminal left in raw mode"
  end
end
