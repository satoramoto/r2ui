# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require "pty"
require "io/console"

# From a pipe (`echo $TOKEN | tool`, CI): read a line silently, never record the value.
class PasswordPipeTest < Minitest::Test
  include R2UI::CLI::Testing

  def ask(input, confirm: false)
    with_shell(input:) { R2UI::CLI.password("Token?", confirm:) }
  end

  def test_reads_a_line
    value, shell = ask("s3cret\n")
    assert_equal "s3cret", value
    assert_equal "", shell.output.string
    assert_equal "✔ Token? · ••••••\n", shell.error.string
  end

  def test_keeps_spaces_in_the_value
    assert_equal "  pass phrase ", ask("  pass phrase \n").first
  end

  def test_masked_line_does_not_show_the_length
    _, short = ask("ab\n")
    _, long = ask("a-very-long-secret-token\n")
    assert_equal short.error.string, long.error.string
  end

  def test_last_line_without_a_newline
    assert_equal "s3cret", ask("s3cret").first
  end

  def test_end_of_input_is_an_error_naming_the_question
    program = R2UI::CLI::Program.build("tool") { run { say(password("Token?").size) } }
    result = run_cli(program, input: "")
    assert_equal 1, result.code
    assert_equal "", result.out
    assert_includes result.err, "Token?"
  end

  def test_confirm_reads_two_matching_lines
    value, shell = ask("s3cret\ns3cret\n", confirm: true)
    assert_equal "s3cret", value
    assert_equal "✔ Token? · ••••••\n", shell.error.string
  end

  def test_confirm_mismatch_from_a_pipe_exits_1_without_the_values
    program = R2UI::CLI::Program.build("tool") { run { say(password("Token?", confirm: true)) } }
    result = run_cli(program, input: "s3cret\nother\n")
    assert_equal 1, result.code
    assert_equal "", result.out
    assert_includes result.err, "✖"
    assert_includes result.err, "Token?"
    refute_includes result.err, "s3cret"
    refute_includes result.err, "other"
  end

  def test_value_reaches_the_command_and_is_never_printed
    program = R2UI::CLI::Program.build("tool") { run { say(password("Token?").reverse) } }
    result = run_cli(program, input: "s3cret\n")
    assert_equal 0, result.code
    assert_equal "terc3s\n", result.out
    refute_includes result.err, "s3cret"
  end
end

# stdin is a terminal, stdout piped (`tool | tee log`): ask on stderr, read without echo.
class PasswordTypedLineTest < Minitest::Test
  # A terminal stdin that hands out lines and records whether echo was off.
  class FakeTerminal
    attr_reader :noecho_reads

    def initialize(*lines)
      @lines = lines
      @noecho_reads = 0
      @echo = true
    end

    def tty? = true

    def gets
      raise "read with echo on" if @echo

      @lines.shift
    end

    def noecho
      @echo = false
      @noecho_reads += 1
      yield self
    ensure
      @echo = true
    end
  end

  def test_asks_on_stderr_and_reads_without_echo
    terminal = FakeTerminal.new("s3cret\n")
    value, shell = ask_untyped(terminal)
    assert_equal "s3cret", value
    assert_equal 1, terminal.noecho_reads
    # The newline the user typed isn't echoed, so the prompt ends its own line.
    assert_equal "Token? \n", shell.error.string
    assert_equal "", shell.output.string
  end

  def test_confirm_asks_twice
    terminal = FakeTerminal.new("s3cret\n", "s3cret\n")
    value, shell = ask_untyped(terminal, confirm: true)
    assert_equal "s3cret", value
    assert_equal 2, terminal.noecho_reads
    assert_equal "Token? \nToken? (again) \n", shell.error.string
  end

  def test_confirm_asks_again_after_a_mismatch
    terminal = FakeTerminal.new("s3cret\n", "typo\n", "s3cret\n", "s3cret\n")
    value, shell = ask_untyped(terminal, confirm: true)
    assert_equal "s3cret", value
    assert_equal "Token? \nToken? (again) \nThey didn't match. Try again.\nToken? \nToken? (again) \n", shell.error.string
  end

  def test_end_of_input_is_an_error
    error = assert_raises(R2UI::CLI::Error) { ask_untyped(FakeTerminal.new) }
    assert_includes error.message, "Token?"
  end

  private

  def ask_untyped(terminal, confirm: false)
    shell = R2UI::CLI::Shell.new(input: terminal, output: StringIO.new, error: StringIO.new, env: {})
    previous = R2UI::CLI.instance_variable_get(:@shell)
    R2UI::CLI.shell = shell
    [R2UI::CLI.password("Token?", confirm:), shell]
  ensure
    R2UI::CLI.shell = previous
  end
end

class PasswordModelTest < Minitest::Test
  include R2UI::CLI::Testing
  K = Bubbletea::KeyMessage

  def setup = R2UI::CLI.require_bubbles!

  def model(confirm: false)
    m = R2UI::CLI::Ext::Password::Model.new(test_shell, "Token?", confirm)
    m.init
    m
  end

  def rune(char) = K.new(key_type: K::KEY_RUNES, runes: [char.ord])

  def key(type) = K.new(key_type: type)

  def type(model, text)
    text.each_char { |c| model, = model.update(rune(c)) }
    model
  end

  def enter(model) = model.update(key(K::KEY_ENTER))

  def plain(text) = text.gsub(/\e\[[0-9;?]*[A-Za-z]/, "")

  def test_echoes_bullets_never_the_value
    m = type(model, "s3cret")
    view = plain(m.view)
    assert_includes view, "? Token? ••••••"
    refute_includes view, "s3cret"
  end

  def test_enter_submits
    m, command = enter(type(model, "s3cret"))
    assert m.done?
    assert_equal "s3cret", m.value
    refute_nil command
    assert_equal "✔ Token? · ••••••", m.view
  end

  def test_answered_line_does_not_show_the_length
    m, = enter(type(model, "ab"))
    assert_equal "✔ Token? · ••••••", m.view
  end

  def test_backspace_edits
    m = type(model, "s3cretx")
    m, = m.update(key(K::KEY_BACKSPACE))
    m, = enter(m)
    assert_equal "s3cret", m.value
  end

  def test_confirm_asks_again
    m, = enter(type(model(confirm: true), "s3cret"))
    refute m.done?
    assert_includes plain(m.view), "? Token? (again)"
    refute_includes plain(m.view), "•"
    m, = enter(type(m, "s3cret"))
    assert m.done?
    assert_equal "s3cret", m.value
    assert_equal "✔ Token? · ••••••", m.view
  end

  def test_confirm_mismatch_starts_over
    m, = enter(type(model(confirm: true), "s3cret"))
    m, = enter(type(m, "typo"))
    refute m.done?
    view = plain(m.view)
    assert_includes view, "? Token?"
    refute_includes view, "(again)"
    assert_includes view, "They didn't match. Try again."
    refute_includes view, "typo"
    m, = enter(type(m, "new"))
    m, = enter(type(m, "new"))
    assert m.done?
    assert_equal "new", m.value
  end

  def test_ctrl_c_and_esc_interrupt
    [key(K::KEY_CTRL_C), key(K::KEY_ESC)].each do |message|
      m, command = type(model, "abc").update(message)
      assert m.interrupted?, message.to_s
      refute_nil command
      assert_equal "✖ Token?", m.view
    end
  end
end

# The inline prompt on a real pseudo-terminal, in this process.
class PasswordTerminalTest < Minitest::Test
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

  def ask(question, confirm: false)
    @asker = Thread.new do
      previous = R2UI::CLI.instance_variable_get(:@shell)
      R2UI::CLI.shell = @shell
      R2UI::CLI.password(question, confirm:)
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

  def test_types_hidden_and_leaves_the_masked_line
    asker = ask("Token?")
    wait_for("Token?")
    @master.write("s3cret")
    wait_for("••••••")
    @master.write("\r")
    assert asker.join(5), "password did not return"
    assert_equal "s3cret", asker.value
    wait_for("✔ Token? · ••••••")
    refute_includes plain, "s3cret"
    assert @slave.echo?, "terminal left in raw mode"
  end

  def test_confirm_on_the_terminal
    asker = ask("Token?", confirm: true)
    wait_for("Token?")
    @master.write("abc\r")
    wait_for("(again)")
    @master.write("abc\r")
    assert asker.join(5), "password did not return"
    assert_equal "abc", asker.value
    wait_for("✔ Token? · ••••••")
    refute_includes plain, "abc"
  end

  def test_ctrl_c_raises_interrupt_and_restores_the_terminal
    asker = ask("Token?")
    wait_for("Token?")
    @master.write("\x03")
    assert_raises(Interrupt) { asker.join(5) }
    wait_for("✖ Token?")
    assert @slave.echo?, "terminal left in raw mode"
  end
end
