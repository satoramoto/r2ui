# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require "pty"
require "io/console"

CHOOSE_MANY_FEATURES = %w[api web worker].freeze

# From a pipe (`echo api,web | tool`, CI): read one line, never ask.
class ChooseManyPipeTest < Minitest::Test
  include R2UI::CLI::Testing

  def pick(input, choices = CHOOSE_MANY_FEATURES, **options)
    with_shell(input:) { R2UI::CLI.choose_many("Features?", choices, **options) }
  end

  def test_labels_return_values_in_list_order
    value, shell = pick("worker, api\n")
    assert_equal %w[api worker], value
    assert_equal "✔ Features? · api, worker\n", shell.error.string
    assert_equal "", shell.output.string
  end

  def test_numbers_are_one_based
    assert_equal %w[api worker], pick("3,1\n").first
  end

  def test_labels_and_numbers_mix_and_repeat
    assert_equal %w[api web], pick("web, 1, api\n").first
  end

  def test_labels_ignore_case
    assert_equal %w[web], pick("WEB\n").first
  end

  def test_hash_choices_map_labels_to_values
    choices = { "API server" => :api, "Web app" => :web }
    value, shell = pick("Web app,1\n", choices)
    assert_equal %i[api web], value
    assert_equal "✔ Features? · API server, Web app\n", shell.error.string
  end

  def test_empty_line_takes_selected
    assert_equal %w[api worker], pick("\n", selected: %w[worker api]).first
  end

  def test_end_of_input_takes_selected
    value, shell = pick("", selected: %w[web])
    assert_equal %w[web], value
    assert_equal "✔ Features? · web\n", shell.error.string
  end

  def test_end_of_input_without_selected_is_none
    value, shell = pick("")
    assert_equal [], value
    assert_equal "✔ Features? · none\n", shell.error.string
  end

  def test_does_not_ask_from_a_pipe
    _, shell = pick("api\n")
    refute_includes shell.error.string, "1. api"
  end

  def test_unknown_choice_is_an_error
    error = assert_raises(R2UI::CLI::Error) { pick("api, db\n") }
    assert_includes error.message, "Features?"
    assert_includes error.message, "\"db\""
    assert_includes error.message, "api, web, worker"
  end

  def test_number_out_of_range_is_an_error
    assert_raises(R2UI::CLI::Error) { pick("4\n") }
    assert_raises(R2UI::CLI::Error) { pick("0\n") }
  end

  def test_too_few_is_an_error
    error = assert_raises(R2UI::CLI::Error) { pick("\n", min: 1) }
    assert_includes error.message, "at least 1"
    assert_includes error.message, "Features?"
  end

  def test_too_many_is_an_error
    error = assert_raises(R2UI::CLI::Error) { pick("1,2,3\n", max: 2) }
    assert_includes error.message, "at most 2"
  end

  def test_bad_arguments_raise
    assert_raises(ArgumentError) { pick("", []) }
    assert_raises(ArgumentError) { pick("", selected: %w[db]) }
    assert_raises(ArgumentError) { pick("", min: 2, max: 1) }
  end

  def test_answer_reaches_the_command
    program = R2UI::CLI::Program.build("tool") do
      run { say(choose_many("Features?", %w[api web worker]).join(" ")) }
    end
    result = run_cli(program, input: "web,api\n")
    assert_equal 0, result.code
    assert_equal "api web\n", result.out
  end

  def test_error_exits_1
    program = R2UI::CLI::Program.build("tool") do
      run { say(choose_many("Features?", %w[api web]).join(" ")) }
    end
    result = run_cli(program, input: "db\n")
    assert_equal 1, result.code
    assert_equal "", result.out
    assert_includes result.err, "✖ "
  end
end

# stdin is a terminal, stdout piped (`tool | tee log`): list the choices and ask on stderr.
class ChooseManyTypedLineTest < Minitest::Test
  class FakeTerminal
    def initialize(*lines) = @lines = lines

    def tty? = true

    def gets = @lines.shift
  end

  def test_lists_choices_and_asks_on_stderr
    value, shell = pick("2\n", selected: %w[api])
    assert_equal %w[web], value
    assert_equal "  1. api\n  2. web\n  3. worker\nFeatures? (comma-separated) [api] ", shell.error.string
    assert_equal "", shell.output.string
  end

  def test_asks_again_after_an_unknown_choice
    value, shell = pick("db\n", "api\n")
    assert_equal %w[api], value
    assert_includes shell.error.string, "Unknown choice \"db\".\nFeatures? (comma-separated) "
  end

  def test_asks_again_when_too_few
    value, shell = pick("\n", "1\n", min: 1)
    assert_equal %w[api], value
    assert_includes shell.error.string, "Pick at least 1."
  end

  def test_end_of_input_takes_selected
    assert_equal %w[worker], pick(selected: %w[worker]).first
  end

  private

  def pick(*lines, **options)
    shell = R2UI::CLI::Shell.new(input: FakeTerminal.new(*lines), output: StringIO.new, error: StringIO.new, env: {})
    previous = R2UI::CLI.instance_variable_get(:@shell)
    R2UI::CLI.shell = shell
    [R2UI::CLI.choose_many("Features?", CHOOSE_MANY_FEATURES, **options), shell]
  ensure
    R2UI::CLI.shell = previous
  end
end

class ChooseManyModelTest < Minitest::Test
  include R2UI::CLI::Testing
  K = Bubbletea::KeyMessage

  def model(choices = CHOOSE_MANY_FEATURES, selected: [], min: 0, max: nil)
    R2UI::CLI::Ext::ChooseMany.build_model(test_shell, "Features?", choices, selected, min, max)
  end

  def rune(char) = K.new(key_type: K::KEY_RUNES, runes: [char.ord])

  def key(type) = K.new(key_type: type)

  def space = key(K::KEY_SPACE)

  def enter = key(K::KEY_ENTER)

  def press(model, *messages)
    command = nil
    messages.each { |message| model, command = model.update(message) }
    [model, command]
  end

  def test_view_before_answering
    assert_equal <<~VIEW.chomp, model(selected: %w[web]).view
      ? Features?
      › ◯ api
        ◉ web
        ◯ worker
      space toggle · a all · enter submit
    VIEW
  end

  def test_space_toggles_and_enter_returns_in_list_order
    m, command = press(model, key(K::KEY_DOWN), key(K::KEY_DOWN), space, key(K::KEY_UP), key(K::KEY_UP), space, enter)
    assert m.done?
    refute_nil command
    assert_equal %w[api worker], m.value
  end

  def test_j_k_move_and_wrap
    m, = press(model, rune("k"), space, rune("j"), space, enter)
    assert_equal %w[api worker], m.value
  end

  def test_space_twice_unchecks
    m, = press(model(selected: %w[api]), space, enter)
    assert_equal [], m.value
  end

  def test_a_toggles_all
    m, = press(model(selected: %w[web]), rune("a"))
    assert_includes m.view, "◉ api"
    refute_includes m.view, "◯"
    m, = press(m, rune("a"), enter)
    assert_equal [], m.value
  end

  def test_enter_waits_until_within_min
    m, command = press(model(min: 1), enter)
    assert_nil command
    refute m.done?
    assert_includes m.view, "Pick at least 1"
    m, = press(m, space, enter)
    assert_equal %w[api], m.value
  end

  def test_enter_waits_until_within_max
    m, command = press(model(max: 1), rune("a"), enter)
    assert_nil command
    refute m.done?
    assert_includes m.view, "Pick at most 1"
    m, = press(m, rune("a"), space, enter)
    assert_equal %w[api], m.value
  end

  def test_hash_choices_return_values
    m, = press(model({ "API" => :api, "Web" => :web }), rune("a"), enter)
    assert_equal %i[api web], m.value
    assert_equal "✔ Features? · API, Web", m.view
  end

  def test_view_after_answering
    m, = press(model(selected: %w[api worker]), enter)
    assert_equal "✔ Features? · api, worker", m.view
    m, = press(model, enter)
    assert_equal "✔ Features? · none", m.view
  end

  def test_ctrl_c_and_esc_interrupt
    [key(K::KEY_CTRL_C), key(K::KEY_ESC)].each do |message|
      m, command = press(model, message)
      assert m.interrupted?
      refute_nil command
      assert_equal "✖ Features?", m.view
    end
  end

  def test_scrolls_past_ten_items
    items = (1..14).map { |n| "item#{n}" }
    m = model(items)
    assert_includes m.view, "item10"
    refute_includes m.view, "item11"
    assert_includes m.view, "↓ 4 more"
    m, = press(m, *Array.new(12) { key(K::KEY_DOWN) })
    assert_includes m.view, "› ◯ item13"
    assert_includes m.view, "↑ 3 more"
    assert_includes m.view, "↓ 1 more"
    refute_includes m.view, "item3\n"
  end
end

# The inline prompt on a real pseudo-terminal, in this process.
class ChooseManyTerminalTest < Minitest::Test
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
      R2UI::CLI.choose_many("Features?", CHOOSE_MANY_FEATURES, selected: %w[web])
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

  def test_toggles_and_submits
    asker = ask
    wait_for("◉ web")
    @master.write(" ")
    wait_for("› ◉ api")
    @master.write("\r")
    assert asker.join(5), "choose_many did not return"
    assert_equal %w[api web], asker.value
    wait_for("✔ Features? · api, web")
    assert @slave.echo?, "terminal left in raw mode"
  end

  def test_ctrl_c_raises_interrupt_and_restores_the_terminal
    asker = ask
    wait_for("Features?")
    @master.write("\x03")
    assert_raises(Interrupt) { asker.join(5) }
    wait_for("✖ Features?")
    assert @slave.echo?, "terminal left in raw mode"
  end
end
