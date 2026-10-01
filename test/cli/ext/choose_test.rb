# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require "pty"
require "io/console"

# From a pipe (`echo us | tool`, CI): read one line, don't ask.
class ChoosePipeTest < Minitest::Test
  include R2UI::CLI::Testing

  REGIONS = %w[eu us ap].freeze

  def choose(input, choices = REGIONS, **options)
    with_shell(input:) { R2UI::CLI.choose("Region?", choices, **options) }
  end

  def test_a_label_picks_it
    value, shell = choose("us\n")
    assert_equal "us", value
    assert_equal "✔ Region? · us\n", shell.error.string
    assert_equal "", shell.output.string
  end

  def test_a_number_picks_that_choice
    assert_equal "ap", choose("3\n").first
    assert_equal "eu", choose(" 1 \n").first
  end

  def test_labels_match_without_case
    assert_equal "us", choose("US\n").first
  end

  def test_hash_maps_labels_to_values
    choices = { "Europe" => :eu, "United States" => :us }
    value, shell = choose("United States\n", choices)
    assert_equal :us, value
    assert_equal "✔ Region? · United States\n", shell.error.string
    assert_equal :eu, choose("1\n", choices).first
  end

  def test_empty_line_takes_the_default
    assert_equal "us", choose("\n", default: "us").first
  end

  def test_end_of_input_takes_the_default
    value, shell = choose("", default: "eu")
    assert_equal "eu", value
    assert_equal "✔ Region? · eu\n", shell.error.string
  end

  def test_default_may_be_a_hash_value_or_label
    choices = { "Europe" => :eu, "United States" => :us }
    assert_equal :us, choose("", choices, default: :us).first
    assert_equal :us, choose("", choices, default: "United States").first
  end

  def test_end_of_input_without_a_default_is_an_error
    error = assert_raises(R2UI::CLI::Error) { choose("") }
    assert_includes error.message, "Region?"
    assert_includes error.message, "eu, us, ap"
  end

  def test_unknown_answer_from_a_pipe_is_an_error
    error = assert_raises(R2UI::CLI::Error) { choose("mars\n") }
    assert_includes error.message, "\"mars\""
    assert_includes error.message, "Region?"
    assert_raises(R2UI::CLI::Error) { choose("4\n") }
    assert_raises(R2UI::CLI::Error) { choose("0\n") }
  end

  def test_unknown_default_is_an_argument_error
    assert_raises(ArgumentError) { choose("", default: "mars") }
  end

  def test_no_choices_is_an_argument_error
    assert_raises(ArgumentError) { choose("", []) }
  end

  def test_answer_reaches_the_command
    program = R2UI::CLI::Program.build("tool") do
      run { say("deploying to #{choose("Region?", %w[eu us ap])}") }
    end
    result = run_cli(program, input: "2\n")
    assert_equal 0, result.code
    assert_equal "deploying to us\n", result.out

    result = run_cli(program, input: "")
    assert_equal 1, result.code
    assert_includes result.err, "✖ "
    assert_includes result.err, "Region?"
  end
end

# stdin is a terminal, stdout piped (`tool | tee log`): list the choices and ask on stderr.
class ChooseTypedLineTest < Minitest::Test
  class FakeTerminal
    def initialize(*lines) = @lines = lines

    def tty? = true

    def gets = @lines.shift
  end

  def test_lists_the_choices_and_asks_on_stderr
    value, shell = ask("2\n", default: "eu")
    assert_equal "us", value
    assert_equal "  1) eu\n  2) us\n  3) ap\nRegion? [eu] ", shell.error.string
    assert_equal "", shell.output.string
  end

  def test_asks_again_after_an_unknown_answer
    value, shell = ask("mars\n", "ap\n")
    assert_equal "ap", value
    assert_equal "  1) eu\n  2) us\n  3) ap\nRegion? Please pick one of the choices or its number (1-3).\nRegion? ",
                 shell.error.string
  end

  def test_asks_again_after_an_empty_line_without_a_default
    assert_equal "eu", ask("\n", "eu\n").first
  end

  def test_end_of_input_takes_the_default
    assert_equal "ap", ask(default: "ap").first
  end

  private

  def ask(*lines, default: nil)
    shell = R2UI::CLI::Shell.new(input: FakeTerminal.new(*lines), output: StringIO.new, error: StringIO.new, env: {})
    previous = R2UI::CLI.instance_variable_get(:@shell)
    R2UI::CLI.shell = shell
    [R2UI::CLI.choose("Region?", %w[eu us ap], default:), shell]
  ensure
    R2UI::CLI.shell = previous
  end
end

class ChooseModelTest < Minitest::Test
  include R2UI::CLI::Testing
  K = Bubbletea::KeyMessage

  def model(choices = %w[eu us ap], default: nil)
    R2UI::CLI::Ext::Choose::Model.new(test_shell, "Region?", R2UI::CLI::Ext::Choose.options(choices),
                                      R2UI::CLI::Ext::Choose.default_index(R2UI::CLI::Ext::Choose.options(choices), default))
  end

  def rune(char) = K.new(key_type: K::KEY_RUNES, runes: [char.ord])

  def key(type) = K.new(key_type: type)

  def press(model, *messages)
    command = nil
    messages.each { |message| model, command = model.update(message) }
    [model, command]
  end

  def test_enter_picks_the_first_without_a_default
    m, command = press(model, key(K::KEY_ENTER))
    assert m.done?
    assert_equal "eu", m.value
    refute_nil command
  end

  def test_enter_picks_the_default
    m, = press(model(default: "us"), key(K::KEY_ENTER))
    assert_equal "us", m.value
  end

  def test_down_and_j_move_down_up_and_k_move_up
    m, = press(model, key(K::KEY_DOWN), rune("j"), key(K::KEY_ENTER))
    assert_equal "ap", m.value
    m, = press(model(default: "ap"), key(K::KEY_UP), key(K::KEY_ENTER))
    assert_equal "us", m.value
    m, = press(model(default: "ap"), rune("k"), rune("k"), key(K::KEY_ENTER))
    assert_equal "eu", m.value
  end

  def test_moving_wraps_around
    m, = press(model, key(K::KEY_UP), key(K::KEY_ENTER))
    assert_equal "ap", m.value
    m, = press(model(default: "ap"), key(K::KEY_DOWN), key(K::KEY_ENTER))
    assert_equal "eu", m.value
  end

  def test_home_and_end
    m, = press(model, key(K::KEY_END), key(K::KEY_ENTER))
    assert_equal "ap", m.value
    m, = press(model(default: "ap"), key(K::KEY_HOME), key(K::KEY_ENTER))
    assert_equal "eu", m.value
  end

  def test_moving_does_not_answer
    m, command = press(model, key(K::KEY_DOWN))
    assert_nil command
    refute m.done?
  end

  def test_returns_hash_values
    m, = press(model({ "Europe" => :eu, "Asia" => :ap }), key(K::KEY_DOWN), key(K::KEY_ENTER))
    assert_equal :ap, m.value
  end

  def test_ctrl_c_and_esc_interrupt
    [key(K::KEY_CTRL_C), key(K::KEY_ESC)].each do |message|
      m, command = press(model, message)
      assert m.interrupted?
      refute_nil command
    end
  end

  def test_view_before_answering
    assert_equal <<~VIEW.chomp, model(default: "us").view
      ? Region? ↑/↓ move · enter pick
          eu
        › us
          ap
    VIEW
  end

  def test_view_after_answering
    m, = press(model, key(K::KEY_DOWN), key(K::KEY_ENTER))
    assert_equal "✔ Region? · us", m.view
    m, = press(model({ "Europe" => :eu }), key(K::KEY_ENTER))
    assert_equal "✔ Region? · Europe", m.view
  end

  def test_view_after_interrupt
    m, = press(model, key(K::KEY_ESC))
    assert_equal "✖ Region?", m.view
  end

  def test_scrolls_past_ten_items_with_hints
    items = (1..14).map { |n| "item#{n}" }
    m = model(items)
    lines = m.view.lines.map(&:chomp)
    assert_equal 12, lines.size
    assert_equal "  › item1", lines[1]
    assert_equal "    item10", lines[10]
    assert_equal "    ↓ 4 more", lines[11]

    m, = press(m, *Array.new(10) { key(K::KEY_DOWN) })
    lines = m.view.lines.map(&:chomp)
    assert_equal "    ↑ 1 more", lines[1]
    assert_equal "  › item11", lines[11]
    assert_equal "    ↓ 3 more", lines[12]

    m, = press(m, key(K::KEY_END))
    lines = m.view.lines.map(&:chomp)
    assert_equal "    ↑ 4 more", lines[1]
    assert_equal "  › item14", lines.last
  end

  def test_a_default_far_down_is_in_view
    items = (1..30).map { |n| "item#{n}" }
    assert_includes model(items, default: "item25").view, "› item25"
  end
end

# The inline prompt on a real pseudo-terminal, in this process.
class ChooseTerminalTest < Minitest::Test
  def setup
    @master, @slave = PTY.open
    @slave.winsize = [20, 60]
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

  def ask
    @asker = Thread.new do
      previous = R2UI::CLI.instance_variable_get(:@shell)
      R2UI::CLI.shell = @shell
      R2UI::CLI.choose("Region?", %w[eu us ap], default: "eu")
    ensure
      R2UI::CLI.shell = previous
    end
    @asker.report_on_exception = false
    @asker
  end

  def plain = @lock.synchronize { @buffer.dup }.gsub(/\e\[[0-9;?]*[A-Za-z]/, "")

  def wait_for(text, timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until plain.include?(text)
      flunk "timed out waiting for #{text.inspect}; output: #{plain.inspect}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.01
    end
  end

  def test_moves_and_picks
    asker = ask
    wait_for("› eu")
    @master.write("j")
    wait_for("› us")
    @master.write("\r")
    assert asker.join(5), "choose did not return"
    assert_equal "us", asker.value
    wait_for("✔ Region? · us")
    assert @slave.echo?, "terminal left in raw mode"
  end

  def test_ctrl_c_raises_interrupt_and_restores_the_terminal
    asker = ask
    wait_for("› eu")
    @master.write("\x03")
    assert_raises(Interrupt) { asker.join(5) }
    wait_for("✖ Region?")
    assert @slave.echo?, "terminal left in raw mode"
  end
end
