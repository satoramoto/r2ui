# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require "pty"
require "io/console"

class ConfirmPipeTest < Minitest::Test
  include R2UI::CLI::Testing

  def ask(input, default: false)
    with_shell(input:) { R2UI::CLI.confirm("Deploy?", default:) }
  end

  def test_yes_answers
    ["y\n", "yes\n", "Y\n", "YES\n", "  yes  \n"].each do |input|
      value, shell = ask(input)
      assert_equal true, value, input.inspect
      assert_equal "✔ Deploy? · yes\n", shell.error.string
      assert_equal "", shell.output.string
    end
  end

  def test_no_answers
    ["n\n", "no\n", "N\n"].each do |input|
      value, shell = ask(input, default: true)
      assert_equal false, value, input.inspect
      assert_equal "✔ Deploy? · no\n", shell.error.string
    end
  end

  def test_empty_line_takes_the_default
    assert_equal false, ask("\n").first
    assert_equal true, ask("\n", default: true).first
  end

  def test_end_of_input_takes_the_default
    value, shell = ask("")
    assert_equal false, value
    assert_equal "✔ Deploy? · no\n", shell.error.string
    assert_equal true, ask("", default: true).first
  end

  def test_does_not_ask_from_a_pipe
    _, shell = ask("y\n")
    refute_includes shell.error.string, "[y/N]"
  end

  def test_unreadable_answer_from_a_pipe_exits_1
    program = R2UI::CLI::Program.build("tool") do
      run { say(confirm("Deploy?") ? "deployed" : "skipped") }
    end
    result = run_cli(program, input: "maybe\n")
    assert_equal 1, result.code
    assert_equal "", result.out
    assert_includes result.err, "✖ expected yes or no for \"Deploy?\", got \"maybe\""
  end

  def test_answer_reaches_the_command
    program = R2UI::CLI::Program.build("tool") do
      run { say(confirm("Deploy?") ? "deployed" : "skipped") }
    end
    assert_equal "deployed\n", run_cli(program, input: "y\n").out
    assert_equal "skipped\n", run_cli(program, input: "\n").out
  end
end

# stdin is a terminal, stdout piped (`tool | tee log`): ask a line on stderr.
class ConfirmTypedLineTest < Minitest::Test
  # A terminal stdin that hands out lines.
  class FakeTerminal
    def initialize(*lines) = @lines = lines

    def tty? = true

    def gets = @lines.shift
  end

  def test_shell_is_not_interactive_but_input_is_a_terminal
    shell = R2UI::CLI::Shell.new(input: FakeTerminal.new, output: StringIO.new, error: StringIO.new, env: {})
    assert shell.input_tty?
    refute shell.interactive?
  end

  def test_asks_on_stderr
    value, shell = ask_untyped("y\n")
    assert_equal true, value
    assert_equal "Deploy? [y/N] ", shell.error.string
    assert_equal "", shell.output.string
  end

  def test_hint_shows_the_default
    _, shell = ask_untyped("\n", default: true)
    assert_equal "Deploy? [Y/n] ", shell.error.string
  end

  def test_asks_again_after_an_unreadable_answer
    value, shell = ask_untyped("maybe\n", "n\n", default: true)
    assert_equal false, value
    assert_equal "Deploy? [Y/n] Please answer yes or no.\nDeploy? [Y/n] ", shell.error.string
  end

  def test_end_of_input_takes_the_default
    assert_equal true, ask_untyped(default: true).first
  end

  private

  # Shell#input_tty? returns `tty:` when it is set, so leave tty unset: stdout is a StringIO
  # (not a terminal) and stdin is the fake terminal.
  def ask_untyped(*lines, default: false)
    shell = R2UI::CLI::Shell.new(input: FakeTerminal.new(*lines), output: StringIO.new, error: StringIO.new, env: {})
    previous = R2UI::CLI.instance_variable_get(:@shell)
    R2UI::CLI.shell = shell
    [R2UI::CLI.confirm("Deploy?", default:), shell]
  ensure
    R2UI::CLI.shell = previous
  end
end

class ConfirmModelTest < Minitest::Test
  include R2UI::CLI::Testing
  K = Bubbletea::KeyMessage

  def model(default: false) = R2UI::CLI::Ext::Confirm::Model.new(test_shell, "Deploy?", default)

  def rune(char) = K.new(key_type: K::KEY_RUNES, runes: [char.ord])

  def key(type) = K.new(key_type: type)

  def press(model, message)
    model, command = model.update(message)
    [model, command]
  end

  def test_y_answers_yes
    m, command = press(model, rune("y"))
    assert m.done?
    assert_equal true, m.value
    refute_nil command
  end

  def test_n_answers_no
    m, = press(model(default: true), rune("N"))
    assert m.done?
    assert_equal false, m.value
  end

  def test_enter_takes_the_default
    m, = press(model, key(K::KEY_ENTER))
    assert_equal false, m.value
    m, = press(model(default: true), key(K::KEY_ENTER))
    assert_equal true, m.value
  end

  def test_left_right_h_l_tab_toggle
    [key(K::KEY_LEFT), key(K::KEY_RIGHT), rune("h"), rune("l"), key(K::KEY_TAB), key(K::KEY_SHIFT_TAB)].each do |message|
      m = model
      m, command = press(m, message)
      assert_nil command, message.to_s
      refute m.done?
      assert_equal true, m.choice, message.to_s
      m, = press(m, key(K::KEY_ENTER))
      assert_equal true, m.value, message.to_s
    end
  end

  def test_toggle_twice_returns
    m = model
    m, = press(m, rune("l"))
    m, = press(m, rune("h"))
    assert_equal false, m.choice
  end

  def test_ctrl_c_and_esc_interrupt
    [key(K::KEY_CTRL_C), key(K::KEY_ESC)].each do |message|
      m, command = press(model, message)
      assert m.interrupted?, message.to_s
      assert m.done?
      refute_nil command
    end
  end

  def test_other_keys_are_ignored
    m, command = press(model, rune("x"))
    assert_nil command
    refute m.done?
  end

  def test_view_before_answering
    assert_equal "? Deploy?    Yes  › No", model.view
    assert_equal "? Deploy?  › Yes    No", model(default: true).view
  end

  def test_view_after_answering
    m, = press(model, rune("y"))
    assert_equal "✔ Deploy? · Yes", m.view
    m, = press(model, rune("n"))
    assert_equal "✔ Deploy? · No", m.view
  end

  def test_view_after_interrupt
    m, = press(model, key(K::KEY_CTRL_C))
    assert_equal "✖ Deploy?", m.view
  end
end

# The inline prompt on a real pseudo-terminal, in this process.
class ConfirmTerminalTest < Minitest::Test
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

  def ask(question)
    @asker = Thread.new do
      previous = R2UI::CLI.instance_variable_get(:@shell)
      R2UI::CLI.shell = @shell
      R2UI::CLI.confirm(question)
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

  def test_shell_is_interactive
    assert @shell.interactive?
  end

  def test_moves_and_picks_yes
    asker = ask("Deploy?")
    wait_for("Deploy?")
    @master.write("l")
    wait_for("› Yes")
    @master.write("\r")
    assert asker.join(5), "confirm did not return"
    assert_equal true, asker.value
    wait_for("✔ Deploy? · Yes")
    assert @slave.echo?, "terminal left in raw mode"
  end

  def test_ctrl_c_raises_interrupt_and_restores_the_terminal
    asker = ask("Deploy?")
    wait_for("Deploy?")
    @master.write("\x03")
    # Thread#join re-raises the thread's exception; a timeout returns nil and fails this.
    assert_raises(Interrupt) { asker.join(5) }
    wait_for("✖ Deploy?")
    assert @slave.echo?, "terminal left in raw mode"
  end
end
